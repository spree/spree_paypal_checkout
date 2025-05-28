pin 'application-spree-paypal-checkout', to: 'spree_paypal_checkout/application.js', preload: false

pin_all_from SpreePaypalCheckout::Engine.root.join('app/javascript/spree_paypal_checkout/controllers'),
             under: 'spree_paypal_checkout/controllers',
             to: 'spree_paypal_checkout/controllers',
             preload: 'application-spree-paypal-checkout'
