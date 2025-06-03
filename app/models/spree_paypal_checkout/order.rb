module SpreePaypalCheckout
  class Order < Base
    class NotCapturedError < StandardError; end
    class AlreadyCapturedError < StandardError; end

    #
    # Associations
    #
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    alias gateway payment_method

    #
    # Callbacks
    #
    before_validation :set_amount_from_order, on: :create

    #
    # Validations
    #
    validates :paypal_id, presence: true, uniqueness: true
    validates :order, :payment_method, :data, presence: true
    validates :amount, numericality: { greater_than: 0 }, presence: true

    store_accessor :data, :payer, :purchase_units, :payment_source, :status

    # Create a Spree::Payment record for this PayPal order
    # @return [Spree::Payment]
    def create_payment!
      raise NotCapturedError unless completed?

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
      raise AlreadyCapturedError if completed?

      CaptureOrder.new(paypal_order: self).call
    end

    # gets the PayPal payment ID from the PayPal order
    # only available for authorized or captured orders
    # @return [String]
    def paypal_payment_id
      @paypal_payment_id ||= data.dig('purchase_units', 0, 'payments', 'captures', 0, 'id')
    end

    # gets the PayPal order from PayPal API
    # @return [PaypalServerSdk::ApiResponse]
    def paypal_order
      @paypal_order ||= gateway.client.orders.get_order({ 'id' => paypal_id })
    end

    def completed?
      status == 'COMPLETED'
    end

    private

    def set_amount_from_order
      self.amount ||= order&.total
    end
  end
end
