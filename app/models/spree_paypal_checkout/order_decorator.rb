module SpreePaypalCheckout
  module OrderDecorator
    def self.prepended(base)
      base.store_accessor :private_metadata, :paypal_order_id

      base.has_many :paypal_checkout_orders, class_name: 'SpreePaypalCheckout::Order', dependent: :destroy, foreign_key: :order_id
    end
  end
end

Spree::Order.prepend(SpreePaypalCheckout::OrderDecorator)
