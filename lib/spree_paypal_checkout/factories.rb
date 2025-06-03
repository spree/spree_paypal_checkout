FactoryBot.define do
  # Define your Spree extensions Factories within this file to enable applications, and other extensions to use and override them.
  #
  # Example adding this to your spec_helper will load these Factories for use:
  # require 'spree_paypal_checkout/factories'
  #

  factory :paypal_checkout_gateway, class: 'SpreePaypalCheckout::Gateway' do
    name { 'PayPal Checkout' }
    preferences do
      {
        client_id: ENV.fetch('PAYPAL_CLIENT_ID', 'client_id_test'),
        client_secret: ENV.fetch('PAYPAL_CLIENT_SECRET', 'client_secret_test'),
        test_mode: true
      }
    end
  end

  factory :paypal_checkout_payment_source, class: 'SpreePaypalCheckout::PaymentSource' do
    gateway_customer_profile_id { 'PAY-CUSTOMER-ID' }
  end

  factory :paypal_checkout_order, class: 'SpreePaypalCheckout::Order' do
    paypal_id { 'PAY-ORDER-ID' }
    order { create(:order) }
    amount { order.total }
    data { JSON.parse(File.read(SpreePaypalCheckout::Engine.root.join('spec', 'fixtures', 'paypal_order.json'))) }

    factory :captured_paypal_checkout_order do
      data { JSON.parse(File.read(SpreePaypalCheckout::Engine.root.join('spec', 'fixtures', 'captured_paypal_order.json'))) }
    end
  end
end
