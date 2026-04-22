require 'net/http'

module SpreePaypalCheckout
  class Gateway < ::Spree::Gateway
    module PaymentSessions
      extend ActiveSupport::Concern

      def session_required?
        !SpreePaypalCheckout::Config[:use_legacy_api]
      end

      def payment_session_class
        Spree::PaymentSessions::PaypalCheckout
      end

      # Creates a PayPal order via the PayPal Orders API and persists
      # a Spree::PaymentSessions::PaypalCheckout record.
      def create_payment_session(order:, amount: nil, external_data: {})
        total = amount.presence || order.total_minus_store_credits

        return nil if total.zero?

        protect_from_error do
          order_presenter = SpreePaypalCheckout::OrderPresenter.new(order)
          paypal_response = client.orders.create_order(order_presenter.to_json)

          payment_session_class.create!(
            order: order,
            payment_method: self,
            amount: total,
            currency: order.currency,
            status: 'pending',
            external_id: paypal_response.data.id,
            customer: order.user,
            external_data: paypal_response.data.as_json
          )
        end
      end

      def update_payment_session(payment_session:, amount: nil, external_data: {})
        attrs = {}
        attrs[:amount] = amount if amount.present?

        if external_data.present?
          attrs[:external_data] = (payment_session.external_data || {}).merge(external_data.stringify_keys)
        end

        payment_session.update!(attrs) if attrs.any?
      end

      # Completes a payment session by capturing the PayPal order,
      # creating the Payment record, and transitioning the session.
      #
      # Does NOT complete the order -- that is handled by Carts::Complete
      # (called by the storefront or by the webhook handler).
      def complete_payment_session(payment_session:, params: {})
        paypal_order_id = payment_session.external_id

        response = client.orders.capture_order({
          'id' => paypal_order_id,
          'prefer' => 'return=representation'
        })

        # Persist capture data outside the lock so it survives if post-capture bookkeeping fails
        payment_session.update!(external_data: response.data.as_json)

        payment_session.order.with_lock do
          if response.data.status == 'COMPLETED'
            payment_session.process if payment_session.can_process?

            payment = payment_session.find_or_create_payment!

            if payment.present? && !payment.completed?
              payment.started_processing! if payment.checkout?
              payment.complete! if payment.can_complete?
            end

            create_profile(payment) if payment&.source.present?

            payment_session.complete unless payment_session.completed?
          else
            payment_session.fail if payment_session.can_fail?
          end
        end
      rescue PaypalServerSdk::APIException => e
        payment_session.fail if payment_session.can_fail?
        raise Spree::Core::GatewayError, "PayPal API error: #{e.message}"
      end

      # Parses incoming PayPal webhook events.
      def parse_webhook_event(raw_body, headers)
        verify_webhook_signature!(raw_body, headers)

        event = JSON.parse(raw_body).with_indifferent_access
        event_type = event[:event_type]
        resource = event[:resource] || {}

        paypal_order_id = extract_order_id_from_webhook(event_type, resource)
        return nil unless paypal_order_id

        payment_session = Spree::PaymentSessions::PaypalCheckout.find_by(
          payment_method: self,
          external_id: paypal_order_id
        )
        return nil unless payment_session

        case event_type
        when 'CHECKOUT.ORDER.APPROVED'
          { action: :authorized, payment_session: payment_session, metadata: { paypal_event: event } }
        when 'PAYMENT.CAPTURE.COMPLETED'
          { action: :captured, payment_session: payment_session, metadata: { paypal_event: event } }
        when 'PAYMENT.CAPTURE.DENIED', 'PAYMENT.CAPTURE.DECLINED'
          { action: :failed, payment_session: payment_session, metadata: { paypal_event: event } }
        when 'PAYMENT.CAPTURE.REVERSED', 'PAYMENT.CAPTURE.REFUNDED'
          { action: :canceled, payment_session: payment_session, metadata: { paypal_event: event } }
        else
          nil
        end
      end

      private

      def extract_order_id_from_webhook(event_type, resource)
        case event_type
        when /\ACHECKOUT\.ORDER\./
          resource['id']
        when /\APAYMENT\.CAPTURE\./
          resource.dig('supplementary_data', 'related_ids', 'order_id')
        end
      end

      def verify_webhook_signature!(raw_body, headers)
        if preferred_webhook_secret.blank?
          return if Rails.env.development? || Rails.env.test?

          raise Spree::PaymentMethod::WebhookSignatureError,
                'PayPal webhook_secret is not configured'
        end

        transmission_id = headers['HTTP_PAYPAL_TRANSMISSION_ID'] || headers['PAYPAL-TRANSMISSION-ID']
        transmission_time = headers['HTTP_PAYPAL_TRANSMISSION_TIME'] || headers['PAYPAL-TRANSMISSION-TIME']
        cert_url = headers['HTTP_PAYPAL_CERT_URL'] || headers['PAYPAL-CERT-URL']
        auth_algo = headers['HTTP_PAYPAL_AUTH_ALGO'] || headers['PAYPAL-AUTH-ALGO']
        transmission_sig = headers['HTTP_PAYPAL_TRANSMISSION_SIG'] || headers['PAYPAL-TRANSMISSION-SIG']

        unless transmission_id && transmission_sig
          raise Spree::PaymentMethod::WebhookSignatureError, 'Missing PayPal webhook headers'
        end

        token = obtain_access_token

        api_base = preferred_test_mode ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com'
        uri = URI("#{api_base}/v1/notifications/verify-webhook-signature")

        payload = {
          auth_algo: auth_algo,
          cert_url: cert_url,
          transmission_id: transmission_id,
          transmission_sig: transmission_sig,
          transmission_time: transmission_time,
          webhook_id: preferred_webhook_secret,
          webhook_event: JSON.parse(raw_body)
        }

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 10
        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{token}"
        })
        request.body = payload.to_json

        response = http.request(request)
        result = JSON.parse(response.body)

        unless result['verification_status'] == 'SUCCESS'
          raise Spree::PaymentMethod::WebhookSignatureError, 'Invalid webhook signature'
        end
      rescue Spree::PaymentMethod::WebhookSignatureError
        raise
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, JSON::ParserError, Errno::ECONNREFUSED => e
        raise Spree::PaymentMethod::WebhookSignatureError, "Webhook verification failed: #{e.message}"
      end

      def obtain_access_token
        api_base = preferred_test_mode ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com'
        uri = URI("#{api_base}/v1/oauth2/token")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 10
        request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/x-www-form-urlencoded' })
        request.basic_auth(preferred_client_id, preferred_client_secret)
        request.body = 'grant_type=client_credentials'

        response = http.request(request)
        JSON.parse(response.body)['access_token']
      end
    end
  end
end
