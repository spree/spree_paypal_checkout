module Spree
  module Api
    module V2
      module Storefront
        class PaypalOrderSerializer < BaseSerializer
          attributes :paypal_id, :data, :amount
        end
      end
    end
  end
end
