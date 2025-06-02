import { Controller } from '@hotwired/stimulus'
import showFlashMessage from 'spree/storefront/helpers/show_flash_message'
import { post, put } from '@rails/request.js'

export default class extends Controller {
  static values = {
    clientKey: String,
    orderNumber: String,
    orderToken: String,
    currency: String,
    amount: Number,
    apiCreateOrderPath: String,
    apiCaptureOrderPath: String,
    apiCheckoutUpdatePath: String,
    returnUrl: String,
  }

  connect() {
    this.initPayPal();

    this.submitTarget = document.querySelector('#checkout-payment-submit')
    this.billingAddressCheckbox = document.querySelector('#order_use_shipping')
    this.billingAddressForm = document.querySelector('form.edit_order')

    // hide submit button
    this.submitTarget.style.display = 'none'
  }

  disconnect() {
    this.submitTarget.style.display = 'block'
  }

  initPayPal() {
    const paypalButtons = window.paypal.Buttons({
      style: {
        shape: "rect",
        layout: "vertical",
        color: "gold",
        label: "paypal",
      },
      message: {
        amount: this.amountValue,
      },
      createOrder: async () => {
        const response = await post(this.apiCreateOrderPathValue, {
          headers: {
            "X-Spree-Order-Token": this.orderTokenValue,
          }
        });

        if (response.ok) {
          const paypalOrder = await response.json;

          if (!paypalOrder.data) {
            console.error('No data in PayPal order response:', paypalOrder);
            throw new Error(paypalOrder.error || 'Failed to create PayPal order');
          }

          const orderId = paypalOrder.data.attributes.paypal_id;
          console.log('PayPal order ID to return:', orderId);

          if (!orderId) {
            console.error('No paypal_id found in response data:', paypalOrder.data);
            throw new Error('No PayPal order ID found in response');
          }

          // Make sure we're returning a string
          return String(orderId);
        } else {
          console.error('Failed to create PayPal order:', response.error);
          showFlashMessage('error', `Sorry, your transaction could not be processed...<br><br>${response.error}`);
          throw new Error(response.error || 'Failed to create PayPal order');
        }
      },
      onApprove: async (data, actions) => {
        const response = await put(
          this.apiCaptureOrderPathValue.replace(this.orderNumberValue, data.orderID),
          {
            headers: {
              "X-Spree-Order-Token": this.orderTokenValue,
            },
          }
        );

        if (response.ok) {
          window.location.href = this.returnUrlValue; 
        } else {
          console.error('Failed to capture PayPal order:', response.error);
          showFlashMessage('error', `Sorry, your transaction could not be processed...<br><br>${response.error}`);
        }
      },
      onError: (err) => {
        showFlashMessage('error', `Your transaction was cancelled...<br><br>${err}`);
      }
    });

    paypalButtons.render(this.element);
  }
}