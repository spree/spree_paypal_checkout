module SpreePaypalCheckout
  class CreatePayment
    def initialize(paypal_order:, order: nil, gateway: nil, amount: nil)
      @paypal_order = paypal_order
      @order = order || paypal_order.order
      @gateway = gateway || paypal_order.gateway
      @amount = amount || paypal_order.amount
    end

    def call
      source = SpreePaypalCheckout::CreateSource.new(
        paypal_payment_source: paypal_order.payment_source,
        gateway: gateway,
        order: order
      ).call

      # sometimes a job is re-tried and creates a double payment record so we need to avoid it!
      payment = order.payments.find_or_initialize_by(
        payment_method_id: gateway.id,
        response_code: paypal_order.paypal_id,
        amount: amount
      )

      payment.source = source if source.present?
      payment.state = 'completed' # we're creating the payment record after the order is captured in PayPal API
      payment.save!
      payment
    end

    private

    attr_reader :order, :gateway, :paypal_order, :amount
  end
end
