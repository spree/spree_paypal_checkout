module SpreePaypalCheckout
  class Base < ::Spree.base_class
    self.abstract_class = true
    self.table_name_prefix = 'spree_paypal_checkout_'
  end
end
