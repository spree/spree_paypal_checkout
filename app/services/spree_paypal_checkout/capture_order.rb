module SpreePaypalCheckout
  class CaptureOrder
    def initialize(paypal_order:)
      @paypal_order = paypal_order
      @order = paypal_order.order
      @gateway = paypal_order.gateway
      @amount = paypal_order.amount
    end

    attr_reader :paypal_order, :order, :gateway, :amount

    def call
      return paypal_order if order.completed? || order.canceled?

      # capture the order in PayPal API
      gateway_response = gateway.capture(
        Money.new(amount, order.currency).cents,
        paypal_order.paypal_id,
        {
          order_id: order.number
        }
      )

      order.with_lock do
        # gateway_response.params is a JSON response from PayPal APIs
        paypal_order.update!(data: gateway_response.params)

        # create the Spree::Payment record
        paypal_order.create_payment!

        # complete the order in Spree
        Spree::Dependencies.checkout_complete_service.constantize.call(order: order)
      end

      paypal_order
    end

    private

    # we need to perform this for quick checkout orders which do not have these fields filled
    def add_customer_information(order, charge)
      billing_details = charge.billing_details
      address = billing_details.address

      order.email ||= billing_details.email
      order.save! if order.email_changed?

      # we don't need to perform this if we already have the billing address filled
      return order if order.bill_address.present? && order.bill_address.valid?

      # determine country...
      country_iso = address.country
      country = Spree::Country.find_by(iso: country_iso) || Spree::Country.default

      # assign new address if we don't have one
      order.bill_address ||= Spree::Address.new(country: country, user: order.user)

      # assign attributes
      order.bill_address.quick_checkout = true # skipping some validations

      # sometimes google pay doesn't provide name (geez)
      first_name = billing_details.name&.split(' ')&.first || order.ship_address&.first_name || order.user&.first_name
      last_name = billing_details.name&.split(' ')&.last || order.ship_address&.last_name || order.user&.last_name

      order.bill_address.first_name ||= first_name
      order.bill_address.last_name ||= last_name
      order.bill_address.phone ||= billing_details.phone
      order.bill_address.address1 ||= address.line1
      order.bill_address.address2 ||= address.line2
      order.bill_address.city ||= address.city
      order.bill_address.zipcode ||= address.postal_code

      state_name = address.state
      if country.states_required?
        order.bill_address.state = country.states.find_all_by_name_or_abbr(state_name)&.first if country.states_required?
      else
        order.bill_address.state_name = state_name
      end

      order.bill_address.state_name ||= state_name

      if order.bill_address.invalid?
        order.bill_address = order.ship_address
      else
        order.bill_address.save!
      end

      order.save!

      copy_bill_info_to_user(order) if order.user.present?

      order
    end

    def copy_bill_info_to_user(order)
      user = order.user
      user.first_name ||= order.bill_address.first_name
      user.last_name ||= order.bill_address.last_name
      user.phone ||= order.bill_address.phone
      user.bill_address_id ||= order.bill_address.id
      user.save! if user.changed?
    end
  end
end
