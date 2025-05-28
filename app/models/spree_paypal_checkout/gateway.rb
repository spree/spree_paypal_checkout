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
      handle_purchase_or_capture(amount_in_cents, payment_source, gateway_options)
    end

    # Capture a previously authorized payment
    def capture(amount_in_cents, authorization, gateway_options = {})
      handle_purchase_or_capture(amount_in_cents, authorization, gateway_options)
    end

    def void(authorization, source, gateway_options = {})
      raise 'Not implemented'
    end

    def cancel(authorization, payment = nil)
      raise 'Not implemented'
    end

    private

    def handle_purchase_or_capture(amount_in_cents, payment_source, gateway_options)
      # protect_from_error do
        order = find_order(gateway_options[:order_id])
        return failure('Order not found') unless order

        binding.pry

        paypal_order = order.paypal_checkout_orders.find_by!(paypal_order_id: order.paypal_checkout_orders.last.paypal_order_id)
        return failure('PayPal order not found') unless paypal_order

        # Capture the payment
        response = client.orders.capture_order(
          paypal_order.paypal_order_id,
          {
            'prefer' => 'return=representation'
          }
        )

        if response.data.status == 'COMPLETED'
          paypal_order.capture!
          success(response.data.id, response.data)
        else
          failure('Failed to capture PayPal payment')
        end
      # end
    end

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
    # rescue PaypalServerSdk::ErrorException => e
    #   Rails.logger.error("PayPal error: #{e.message}")
    #   failure(e.message)
    # rescue StandardError => e
    #   Rails.logger.error("PayPal error: #{e.message}")
    #   failure(e.message)
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
