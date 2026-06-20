require 'paypal_server_sdk'

module SpreePaypalCheckout
  class OrderPresenter
    include PaypalServerSdk

    PAYPAL_ITEM_NAME_MAX_LENGTH = 127

    def initialize(order)
      @order = order
    end

    attr_reader :order

    def to_json
      {
        'body' => OrderRequest.new(
          intent: CheckoutPaymentIntent::CAPTURE,
          purchase_units: [purchase_unit],
          payment_source: payment_source
        )
      }
    end

    private

    # The address is collected on the storefront before the PayPal order is
    # created, so we send it to PayPal and pin it (SET_PROVIDED_ADDRESS) rather
    # than letting PayPal collect/override it. This keeps the storefront as the
    # single source of truth for the address — the buyer is not asked for it a
    # second time inside the PayPal wallet, and the captured order carries the
    # same address Spree already has.
    def purchase_unit
      args = {
        amount: amount_with_breakdown,
        items: items
      }
      args[:shipping] = shipping_details if shipping_details

      PurchaseUnitRequest.new(**args)
    end

    # NOTE: the breakdown only sends additional (non-included) tax — sending the
    # full tax_total double-counts VAT on tax-inclusive markets and trips
    # AMOUNT_MISMATCH (the reason this gem is forked). Do not change to
    # order.tax_total.
    def amount_with_breakdown
      AmountWithBreakdown.new(
        currency_code: order.currency.upcase,
        value: order.total.to_s,
        breakdown: AmountBreakdown.new(
          item_total: Money.new(
            currency_code: order.currency.upcase,
            value: order.item_total.to_s
          ),
          shipping: Money.new(
            currency_code: order.currency.upcase,
            value: order.ship_total.to_s
          ),
          tax_total: Money.new(
            currency_code: order.currency.upcase,
            value: order.additional_tax_total.to_s
          ),
          discount: Money.new(
            currency_code: order.currency.upcase,
            value: (order.promo_total || 0).abs.to_s
          )
        )
      )
    end

    def items
      order.line_items.map do |line_item|
        Item.new(
          name: line_item.name.to_s[0...PAYPAL_ITEM_NAME_MAX_LENGTH],
          unit_amount: Money.new(
            currency_code: order.currency.upcase,
            value: line_item.price.to_s
          ),
          quantity: line_item.quantity.to_s,
          sku: line_item.sku,
          category: line_item.variant.digital? ? ItemCategory::DIGITAL_GOODS : ItemCategory::PHYSICAL_GOODS
        )
      end
    end

    def shipping_details
      address = order.ship_address
      return nil if address.blank?

      ShippingDetails.new(
        name: ShippingName.new(full_name: address.full_name),
        address: Address.new(
          country_code: address.country&.iso,
          address_line_1: address.address1,
          address_line_2: address.address2.presence,
          admin_area_2: address.city,
          admin_area_1: region_code(address),
          postal_code: address.zipcode
        )
      )
    end

    # PayPal's admin_area_1 expects the region/state code where one exists
    # (e.g. "CA"); markets without coded states (most of UK/EU) fall back to the
    # free-text region name.
    def region_code(address)
      address.state&.abbr.presence || address.state_name.presence
    end

    # Pin the storefront-collected shipping address so the PayPal wallet does
    # not ask for it again; NO_SHIPPING for orders with no shipping address
    # (e.g. digital-only) so no shipping step is shown at all.
    def payment_source
      PaymentSource.new(
        paypal: PaypalWallet.new(
          experience_context: PaypalWalletExperienceContext.new(
            brand_name: order.store&.name,
            shipping_preference: shipping_preference,
            user_action: PaypalExperienceUserAction::PAY_NOW
          )
        )
      )
    end

    def shipping_preference
      if order.ship_address.present?
        ShippingPreference::SET_PROVIDED_ADDRESS
      else
        ShippingPreference::NO_SHIPPING
      end
    end
  end
end
