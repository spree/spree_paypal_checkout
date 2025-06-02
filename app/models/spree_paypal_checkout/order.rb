module SpreePaypalCheckout
  class Order < Base
    #
    # Associations
    #
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    alias gateway payment_method

    #
    # Validations
    #
    validates :paypal_id, presence: true, uniqueness: true
    validates :data, presence: true

    store_accessor :data, :payer, :purchase_units, :payment_source

    # Create a Spree::Payment record for this PayPal order
    # @return [Spree::Payment]
    def create_payment!
      SpreePaypalCheckout::CreatePayment.new(
        order: order,
        paypal_order: self,
        gateway: payment_method,
        amount: amount
      ).call
    end

    # Capture the PayPal order in PayPal API
    # @return [SpreePaypalCheckout::Order]
    def capture!
      CaptureOrder.new(paypal_order: self).call
    end

    # gets the PayPal payment ID from the PayPal order
    # only available for authorized or captured orders
    # @return [String]
    def paypal_payment_id
      # Get fresh data from PayPal API
      response = paypal_order
      return nil unless response&.data&.purchase_units&.first&.payments&.captures&.first

      # Return the capture ID directly (e.g. "5UX50114VU009815S")
      response.data.purchase_units.first.payments.captures.first.id
    end

    # gets the PayPal order from PayPal API
    # @return [PaypalServerSdk::ApiResponse]
    def paypal_order
      @paypal_order ||= gateway.client.orders.get_order({ 'id' => paypal_id })
    end
  end
end
