module SpreePaypalCheckout
  class Order < Base
    belongs_to :order, class_name: 'Spree::Order'

    validates :paypal_order_id, presence: true, uniqueness: true
    validates :data, presence: true

    state_machine :status, initial: :pending do
      event :capture do
        transition from: :pending, to: :captured
      end
    end

    def charge

    end
  end
end
