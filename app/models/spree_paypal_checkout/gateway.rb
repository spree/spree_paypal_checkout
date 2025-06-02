module SpreePaypalCheckout
  class Gateway < ::Spree::Gateway
    include PaypalServerSdk

    preference :client_id, :password
    preference :client_secret, :password
    preference :test_mode, :boolean, default: true

    preference :venmo_enabled, :boolean, default: true
    preference :paylater_enabled, :boolean, default: true
    preference :card_enabled, :boolean, default: true

    validates :preferred_client_id, :preferred_client_secret, presence: true

    def provider_class
      self.class
    end

    def payment_source_class
      SpreePaypalCheckout::PaymentSources::Paypal
    end

    def payment_profiles_supported?
      true
    end

    def default_name
      'PayPal'
    end

    def method_type
      'spree_paypal_checkout'
    end

    def payment_icon_name
      'paypal'
    end

    def description_partial_name
      'spree_paypal_checkout'
    end

    def source_partial_name
      'paypal_checkout'
    end

    def create_profile(_payment)
      # we don't need to create a profile for PayPal users, everything is handled by PayPal
    end

    def client
      @client ||= Client.new(
        client_credentials_auth_credentials: ClientCredentialsAuthCredentials.new(
          o_auth_client_id: preferred_client_id,
          o_auth_client_secret: preferred_client_secret
        ),
        environment: preferred_test_mode ? Environment::SANDBOX : Environment::PRODUCTION,
        logging_configuration: LoggingConfiguration.new(
          log_level: Logger::INFO,
          request_logging_config: RequestLoggingConfiguration.new(
            log_body: true
          ),
          response_logging_config: ResponseLoggingConfiguration.new(
            log_headers: true
          )
        )
      )
    end

    def authorize(amount_in_cents, payment_source, gateway_options = {})
      raise 'Not implemented'
    end

    # Purchase is the same as authorize + capture in one step
    def purchase(amount_in_cents, payment_source, gateway_options = {})
      capture(amount_in_cents, payment_source.paypal_id, gateway_options)
    end

    # Capture a previously authorized payment
    # @param amount_in_cents [Integer] the amount in cents to capture
    # @param paypal_id [String] the PayPal Order ID
    # @param gateway_options [Hash] this is an instance of Spree::Payment::GatewayOptions.to_hash
    def capture(amount_in_cents, paypal_id, gateway_options = {})
      protect_from_error do
        order = find_order(gateway_options[:order_id])
        return failure('Order not found') unless order

        response = client.orders.capture_order({
          'id' => paypal_id,
          'prefer' => 'return=representation'
        })

        if response.data.status == 'COMPLETED'
          success(response.data.id, response.data.as_json)
        else
          failure('Failed to capture PayPal payment', response.data)
        end
      end
    end

    def void(authorization, source, gateway_options = {})
      raise 'Not implemented'
    end

    def credit(amount_in_cents, _payment_source, paypal_payment_id, gateway_options = {})
      refund_originator = gateway_options[:originator]
      order = refund_originator.respond_to?(:order) ? refund_originator.order : refund_originator

      return failure('Order not found') unless order

      protect_from_error do
        payload = {
          capture_id: paypal_payment_id,
          amount: {
            value: (amount_in_cents / 100.0).to_s,
            currency_code: order.currency.upcase
          }
        }.deep_stringify_keys

        response = client.payments.refund_captured_payment(payload)

        success(response.data.id, response.data.as_json)
      end
    end

    def cancel(authorization, payment = nil)
      raise 'Not implemented'
    end

    private

    def find_order(order_id)
      return nil unless order_id

      order_number, _payment_number = order_id.split('-')
      Spree::Order.find_by(number: order_number)
    end

    def find_capture_id(order_data)
      return nil unless order_data

      # Navigate through the order data to find the capture ID
      order_data.dig('purchase_units', 0, 'payments', 'captures', 0, 'id')
    end

    def protect_from_error
      yield
    rescue PaypalServerSdk::APIException => e
      Rails.logger.error("PayPal error: #{e.message}")
      failure(e.message)
    end

    def success(authorization, response)
      ActiveMerchant::Billing::Response.new(
        true,
        'Transaction successful',
        response,
        authorization: authorization
      )
    end

    def failure(message, response = {})
      ActiveMerchant::Billing::Response.new(
        false,
        message,
        response
      )
    end
  end
end
