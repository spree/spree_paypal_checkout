module SpreePaypalCheckout
  class CreateSource
    def initialize(paypal_payment_source:, gateway:, order: nil, user: nil)
      @paypal_payment_source = paypal_payment_source
      @gateway = gateway
      @user = user || order&.user
      @order = order
    end

    # TODO: add support for venmo and other providers
    def call
      if paypal_payment_source['paypal'].present?
        create_paypal_source
      else
        raise 'Invalid payment source', paypal_payment_source
      end
    end

    private

    attr_reader :gateway, :user, :paypal_payment_source, :order

    # "payment_source": {
    #   "paypal": {
    #     "email_address": "sb-fxqy4743082799@personal.example.com",
    #     "account_id": "RX8ZD67CZ67RU",
    #     "account_status": "VERIFIED",
    #     "name": {
    #       "given_name": "John",
    #       "surname": "Doe"
    #     },
    #     "address": {
    #       "country_code": "US"
    #     }
    #   }
    # },
    def create_paypal_source
      source = SpreePaypalCheckout::PaymentSources::Paypal.find_or_create_by!(
        payment_method: gateway,
        user: user,
        gateway_payment_profile_id: paypal_payment_source['paypal']['account_id']
      )
      source.update!(
        email: paypal_payment_source['paypal']['email_address'],
        name: "#{paypal_payment_source['paypal']['name']['given_name']} #{paypal_payment_source['paypal']['name']['surname']}".strip,
        account_id: paypal_payment_source['paypal']['account_id'],
        account_status: paypal_payment_source['paypal']['account_status']
      )
      source
    end
  end
end
