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
          purchase_units: [
            PurchaseUnitRequest.new(
              amount: AmountWithBreakdown.new(
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
                  # PayPal requires amount.value == item_total + tax_total +
                  # shipping - discount, and item_total == Σ(items.unit_amount).
                  # For tax-INCLUSIVE stores (e.g. UK/EU VAT) the VAT is already
                  # baked into the gross line prices (item_total / unit_amount),
                  # so sending order.tax_total here (which includes that same VAT)
                  # double-counts it and PayPal rejects the order with
                  # UNPROCESSABLE_ENTITY / AMOUNT_MISMATCH. Only ADDITIONAL
                  # (tax-exclusive) tax is added on top of the item prices, so
                  # that is what belongs in the breakdown. For tax-exclusive
                  # stores included_tax_total is 0, so additional_tax_total ==
                  # tax_total and behaviour is unchanged.
                  tax_total: Money.new(
                    currency_code: order.currency.upcase,
                    value: order.additional_tax_total.to_s
                  ),
                  discount: Money.new(
                    currency_code: order.currency.upcase,
                    value: (order.promo_total || 0).abs.to_s
                  )
                )
              ),
              items: order.line_items.map do |line_item|
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
            )
          ]
        )
      }
    end
  end
end
