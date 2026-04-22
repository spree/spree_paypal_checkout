module Spree
  class PaymentSessions::PaypalCheckout < PaymentSession
    def paypal_order_id
      external_id
    end

    def paypal_capture_id
      external_data&.dig('purchase_units', 0, 'payments', 'captures', 0, 'id')
    end

    def paypal_payer
      external_data&.dig('payer')
    end

    def paypal_payment_source
      external_data&.dig('payment_source')
    end

    def accepted?
      external_data&.dig('status') == 'COMPLETED'
    end

    def successful?
      accepted?
    end

    # Creates or finds the Spree::Payment for this session.
    # Defers creation until paypal_capture_id is present so response_code
    # is always the capture ID (required for refunds via Gateway#credit).
    def find_or_create_payment!(metadata = {})
      return unless persisted?
      return payment if payment.present?
      return unless paypal_capture_id

      order.with_lock do
        existing_payment = order.payments.where(
          payment_method: payment_method,
          response_code: paypal_capture_id
        ).first

        return existing_payment if existing_payment.present?

        source = create_payment_source!

        order.payments.create!(
          payment_method: payment_method,
          amount: amount,
          response_code: paypal_capture_id,
          source: source,
          skip_source_requirement: true
        )
      end
    end

    private

    def create_payment_source!
      paypal_data = paypal_payment_source&.dig('paypal')
      return nil unless paypal_data

      source = SpreePaypalCheckout::PaymentSources::Paypal.find_or_initialize_by(
        payment_method: payment_method,
        user: order.user,
        gateway_payment_profile_id: paypal_data['account_id']
      )
      source.update!(
        email: paypal_data['email_address'],
        name: "#{paypal_data.dig('name', 'given_name')} #{paypal_data.dig('name', 'surname')}".strip,
        account_id: paypal_data['account_id'],
        account_status: paypal_data['account_status']
      )
      source
    end
  end
end
