module SpreePaypalCheckout
  module PaymentMethodDecorator
    PAYPAL_CHECKOUT_TYPE = 'SpreePaypalCheckout::Gateway'.freeze

    def self.prepended(base)
      base.scope :paypal_checkout, -> { where(type: PAYPAL_CHECKOUT_TYPE) }
    end

    def paypal_checkout?
      type == PAYPAL_CHECKOUT_TYPE
    end
  end
end

Spree::PaymentMethod.prepend(SpreePaypalCheckout::PaymentMethodDecorator)
