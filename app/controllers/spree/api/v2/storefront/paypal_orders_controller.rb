module Spree
  module Api
    module V2
      module Storefront
        class PaypalOrdersController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::Storefront::OrderConcern

          before_action :require_paypal_checkout_gateway

          # POST /api/v2/storefront/paypal_orders
          def create
            order_presenter = SpreePaypalCheckout::OrderPresenter.new(spree_current_order)

            paypal_response = paypal_client.orders.create_order(order_presenter.to_json)

            paypal_order = spree_current_order.paypal_checkout_orders.create!(
              paypal_order_id: paypal_response.data.id,
              data: paypal_response.data.as_json
            )

            render_serialized_payload { serialize_resource(paypal_order) }
          rescue PaypalServerSdk::ErrorException => e
            render_error_payload(e.message)
          end

          # PUT /api/v2/storefront/paypal_orders/:id/capture
          def capture
            paypal_order = spree_current_order.paypal_checkout_orders.find_by!(paypal_order_id: params[:id])

            # capture the order in PayPal using the gateway
            result = current_store.paypal_checkout_gateway.capture(
              spree_current_order.total,
              paypal_order.paypal_order_id,
              { order_id: spree_current_order.number, paypal_order_id: paypal_order.paypal_order_id }
            )

            binding.pry

            # flag the order as captured
            paypal_order.capture!

            render_serialized_payload { serialize_resource(paypal_order) }
          # rescue PaypalServerSdk::ErrorException => e
            # render_error_payload(e.message)
          end

          private

          def resource_serializer
            Spree::Api::V2::Storefront::PaypalOrderSerializer
          end

          def paypal_client
            @paypal_client ||= current_store.paypal_checkout_gateway.client
          end

          def require_paypal_checkout_gateway
            unless current_store.paypal_checkout_gateway.present?
              render_error_payload('Paypal checkout gateway not found')
            end
          end
        end
      end
    end
  end
end
