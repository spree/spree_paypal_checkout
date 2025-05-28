import { Controller } from '@hotwired/stimulus'
import showFlashMessage from 'spree/storefront/helpers/show_flash_message'

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
        try {
          const response = await fetch(this.apiCreateOrderPathValue, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-Spree-Order-Token": this.orderTokenValue,
            }
          });

          const paypalOrder = await response.json();
          console.log('Full PayPal order response:', paypalOrder);

          if (!paypalOrder.data) {
            console.error('No data in PayPal order response:', paypalOrder);
            throw new Error(paypalOrder.error || 'Failed to create PayPal order');
          }

          const orderId = paypalOrder.data.attributes.paypal_order_id;
          console.log('PayPal order ID to return:', orderId);

          if (!orderId) {
            console.error('No paypal_order_id found in response data:', paypalOrder.data);
            throw new Error('No PayPal order ID found in response');
          }

          // Make sure we're returning a string
          return String(orderId);
        } catch (error) {
          console.error('PayPal createOrder error:', error);
          showFlashMessage('error', `Could not initiate PayPal Checkout...<br><br>${error.message}`);
          throw error;
        }
      },
      onApprove: async (data, actions) => {
        try {
          const response = await fetch(
            // we need to replace the order number with the PayPal order ID
            this.apiCaptureOrderPathValue.replace(this.orderNumberValue, data.orderID),
            {
              method: "PUT",
              headers: {
                "Content-Type": "application/json",
                "X-Spree-Order-Token": this.orderTokenValue,
              },
            }
          );

          const orderData = await response.json().data.attributes.data;
          console.log('Full PayPal order response:', orderData);

          // Three cases to handle:
          //   (1) Recoverable INSTRUMENT_DECLINED -> call actions.restart()
          //   (2) Other non-recoverable errors -> Show a failure message
          //   (3) Successful transaction -> Show confirmation or thank you message

          const errorDetail = orderData?.details?.[0];

          if (errorDetail?.issue === "INSTRUMENT_DECLINED") {
            // (1) Recoverable INSTRUMENT_DECLINED -> call actions.restart()
            // recoverable state, per
            // https://developer.paypal.com/docs/checkout/standard/customize/handle-funding-failures/
            return actions.restart();
          } else if (errorDetail) {
            // (2) Other non-recoverable errors -> Show a failure message
            throw new Error(
              `${errorDetail.description} (${orderData.debug_id})`
            );
          } else if (!orderData.purchase_units) {
            throw new Error(JSON.stringify(orderData));
          } else {
            window.location.href = this.returnUrlValue;
          }
        } catch (error) {
          console.error(error);
          showFlashMessage('error', `Sorry, your transaction could not be processed...<br><br>${error}`);
        }
      },
      onError: (err) => {
        showFlashMessage('error', `Your transaction was cancelled...<br><br>${err}`);
      }
    });

    paypalButtons.render(this.element);
  }
}