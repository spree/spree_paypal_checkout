Rails.application.config.after_initialize do
  Rails.application.config.spree.payment_methods << SpreePaypalCheckout::Gateway

  if Rails.application.config.respond_to?(:spree_storefront)
    Rails.application.config.spree_storefront.head_partials << 'spree_paypal_checkout/head'
  end
end
