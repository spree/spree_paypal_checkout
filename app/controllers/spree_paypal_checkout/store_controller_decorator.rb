module SpreePaypalCheckout
  module StoreControllerDecorator
    def self.prepended(base)
      base.helper SpreePaypalCheckout::BaseHelper
    end
  end
end

Spree::StoreController.prepend(SpreePaypalCheckout::StoreControllerDecorator) if defined?(Spree::StoreController)
