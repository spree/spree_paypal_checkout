module Spree
  module Api
    module V2
      module Storefront
        class PaypalOrderSerializer < BaseSerializer
          attributes :paypal_order_id, :status, :captured_at, :data
        end
      end
    end
  end
end
