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

    def billing_details
      {
        name: payer.dig('name', 'given_name') + ' ' + payer.dig('name', 'surname'),
        email: payer['email_address'],
        phone: payer.dig('phone', 'phone_number', 'national_number'),
        address: {
          address1: payer.dig('address', 'address_line_1'),
          address2: payer.dig('address', 'address_line_2'),
          city: payer.dig('address', 'admin_area_2'),
          zipcode: payer.dig('address', 'postal_code'),
          state: payer.dig('address', 'admin_area_1'),
          country_iso: payer.dig('address', 'country_code')
        }
      }
    end
  end
end
