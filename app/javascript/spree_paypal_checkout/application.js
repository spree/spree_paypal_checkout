import '@hotwired/turbo-rails'
import { Application } from '@hotwired/stimulus'

let application

if (typeof window.Stimulus === "undefined") {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}

import CheckoutPaypalController from 'spree_paypal_checkout/controllers/checkout_paypal_controller'

application.register('checkout-paypal', CheckoutPaypalController)