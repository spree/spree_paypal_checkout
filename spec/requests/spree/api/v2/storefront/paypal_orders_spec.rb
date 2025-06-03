require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::PaypalOrdersController, type: :request do
  let(:store) { create(:store) }
  let(:gateway) { create(:paypal_checkout_gateway, stores: [store]) }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:headers) { { 'X-Spree-Order-Token' => order.token } }

  before do
    allow_any_instance_of(Spree::Api::V2::BaseController).to receive(:current_store).and_return(store)
  end

  describe 'POST /api/v2/storefront/paypal_orders' do
    context 'when paypal checkout gateway exists' do
      before { gateway }

      it 'creates a paypal order', :vcr do
        VCR.use_cassette('paypal/create_order') do
          expect {
            post '/api/v2/storefront/paypal_orders', headers: headers
          }.to change(SpreePaypalCheckout::Order, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(json_response['data']['attributes']['paypal_id']).to be_present
          expect(json_response['data']['attributes']['amount']).to eq(order.total.to_s)
          expect(json_response['data']['attributes']['data']).to be_kind_of(Hash)

          paypal_order = SpreePaypalCheckout::Order.last
          expect(paypal_order.order).to eq(order)
          expect(paypal_order.payment_method).to eq(gateway)
          expect(paypal_order.amount).to eq(order.total)
        end
      end
    end

    context 'when paypal checkout gateway does not exist' do
      it 'returns error' do
        post '/api/v2/storefront/paypal_orders', headers: headers

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Paypal checkout gateway not found')
      end
    end
  end

  xdescribe 'PUT /api/v2/storefront/paypal_orders/:id/capture' do
    let(:paypal_order) { create(:paypal_checkout_order, order: order, payment_method: gateway) }

    context 'when paypal order exists' do
      it 'captures the paypal order', :vcr do
        VCR.use_cassette('paypal/capture_order') do
          expect {
            put "/api/v2/storefront/paypal_orders/#{paypal_order.paypal_id}/capture"
          }.to change { paypal_order.reload.captured? }.from(false).to(true)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when paypal order does not exist' do
      it 'returns not found' do
        put '/api/v2/storefront/paypal_orders/non_existent_id/capture'

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
