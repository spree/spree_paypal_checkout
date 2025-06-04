require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::PaypalOrdersController, type: :request do
  let(:store) { create(:store) }
  let(:gateway) { create(:paypal_checkout_gateway, stores: [store]) }
  let(:user) { create(:user) }
  let(:address) { create(:address, user: user) }
  let(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment', ship_address: address, bill_address: address) }
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

  describe 'PUT /api/v2/storefront/paypal_orders/:id/capture' do
    let(:paypal_order) { create(:paypal_checkout_order, order: order, payment_method: gateway, paypal_id: paypal_id) }

    context 'when paypal order record exists' do
      context 'paypal ID is not found in PayPal API' do
        let(:paypal_id) { 'non_existent_id' }

        it 'renders error', :vcr do
          VCR.use_cassette('paypal/capture_order_not_found') do
            put "/api/v2/storefront/paypal_orders/#{paypal_order.paypal_id}/capture", headers: headers
            expect(response).to have_http_status(:unprocessable_entity)
            expect(json_response['error']).to eq('PayPal API error: The specified resource does not exist.')
          end
        end
      end

      context 'paypal ID is found in PayPal API' do
        let(:paypal_id) { '5RX55415GL5517636' } # id of a created and confirmed order (confirmed via PayPal JS SDK)

        it "captures the order" do
          gateway # create the gateway to make sure it's available in the cassette

          VCR.use_cassette('paypal/capture_order') do
            put "/api/v2/storefront/paypal_orders/#{paypal_order.paypal_id}/capture", headers: headers
            expect(response).to have_http_status(:ok)

            expect(json_response['data']['attributes']['paypal_id']).to eq(paypal_order.paypal_id)
            expect(json_response['data']['attributes']['amount']).to eq(order.total.to_s)
            expect(json_response['data']['attributes']['data']).to be_kind_of(Hash)

            expect(order.reload.completed?).to be(true)
            expect(order.payments.count).to eq(1)
            expect(order.payments.first.state).to eq('completed')
            expect(order.payments.first.amount).to eq(order.total)
            expect(order.payments.first.payment_method).to eq(gateway)
            expect(order.payments.first.source).to be_kind_of(SpreePaypalCheckout::PaymentSources::Paypal)
          end
        end
      end
    end

    context 'when paypal order record does not exist' do
      it 'returns not found' do
        put '/api/v2/storefront/paypal_orders/non_existent_id/capture'

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
