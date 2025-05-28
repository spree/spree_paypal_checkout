module SpreePaypalCheckout
  module StoreDecorator
    def paypal_checkout_gateway
      @paypal_checkout_gateway ||= payment_methods.paypal_checkout.active.last
    end
  end
end

Spree::Store.prepend(SpreePaypalCheckout::StoreDecorator)
