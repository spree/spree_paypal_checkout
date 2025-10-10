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
                  tax_total: Money.new(
                    currency_code: order.currency.upcase,
                    value: order.tax_total.to_s
                  ),
                  discount: Money.new(
                    currency_code: order.currency.upcase,
                    value: order.promo_total.abs.to_s
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
