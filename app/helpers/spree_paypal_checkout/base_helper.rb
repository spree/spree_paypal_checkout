module SpreePaypalCheckout
  module BaseHelper
    def current_paypal_checkout_gateway
      @current_paypal_checkout_gateway ||= current_store.paypal_checkout_gateway
    end

    def paypal_checkout_enabled?
      current_paypal_checkout_gateway.present?
    end
  end
end
