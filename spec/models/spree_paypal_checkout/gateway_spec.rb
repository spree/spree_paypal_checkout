require 'spec_helper'

RSpec.describe SpreePaypalCheckout::Gateway do
  let(:store) { create(:store) }
  let(:gateway) { create(:paypal_checkout_gateway, stores: [store]) }

  describe 'validations' do
    it 'requires client_id' do
      gateway.preferred_client_id = nil
      expect(gateway).not_to be_valid
      expect(gateway.errors[:preferred_client_id]).to include("can't be blank")
    end

    it 'requires client_secret' do
      gateway.preferred_client_secret = nil
      expect(gateway).not_to be_valid
      expect(gateway.errors[:preferred_client_secret]).to include("can't be blank")
    end
  end

  describe '#provider_class' do
    it 'returns self class' do
      expect(gateway.provider_class).to eq(described_class)
    end
  end

  describe '#payment_source_class' do
    it 'returns SpreePaypalCheckout::PaymentSources::Paypal' do
      expect(gateway.payment_source_class).to eq(SpreePaypalCheckout::PaymentSources::Paypal)
    end
  end

  describe '#payment_profiles_supported?' do
    it 'returns true' do
      expect(gateway.payment_profiles_supported?).to be true
    end
  end

  describe '#default_name' do
    it 'returns PayPal' do
      expect(gateway.default_name).to eq('PayPal')
    end
  end

  describe '#method_type' do
    it 'returns spree_paypal_checkout' do
      expect(gateway.method_type).to eq('spree_paypal_checkout')
    end
  end

  describe '#payment_icon_name' do
    it 'returns paypal' do
      expect(gateway.payment_icon_name).to eq('paypal')
    end
  end

  describe '#description_partial_name' do
    it 'returns spree_paypal_checkout' do
      expect(gateway.description_partial_name).to eq('spree_paypal_checkout')
    end
  end

  describe '#configuration_guide_partial_name' do
    it 'returns spree_paypal_checkout' do
      expect(gateway.configuration_guide_partial_name).to eq('spree_paypal_checkout')
    end
  end

  describe '#source_partial_name' do
    it 'returns paypal_checkout' do
      expect(gateway.source_partial_name).to eq('paypal_checkout')
    end
  end

  describe '#create_profile' do
    let(:user) { create(:user) }
    let(:order) { create(:order_with_line_items, user: user, store: store) }
    let(:payment_source) do
      SpreePaypalCheckout::PaymentSources::Paypal.create!(payment_method: gateway)
    end
    let(:payment) { create(:payment, order: order, payment_method: gateway, source: payment_source, amount: order.total) }

    context 'when payment source is a PayPal source with an account_id' do
      let(:payment_source) do
        SpreePaypalCheckout::PaymentSources::Paypal.create!(
          payment_method: gateway,
          account_id: 'PAYPAL-ACCOUNT-123'
        )
      end

      it 'creates a gateway customer record' do
        expect { gateway.create_profile(payment) }.to change(Spree::GatewayCustomer, :count).by(1)

        customer = gateway.gateway_customers.last
        expect(customer.user).to eq(user)
        expect(customer.profile_id).to eq('PAYPAL-ACCOUNT-123')
      end

      it 'does not create a duplicate gateway customer' do
        gateway.create_profile(payment)
        expect { gateway.create_profile(payment) }.not_to change(Spree::GatewayCustomer, :count)
      end
    end

    context 'when order has no user' do
      let(:order) { create(:order_with_line_items, user: nil, store: store) }

      it 'returns nil' do
        expect(gateway.create_profile(payment)).to be_nil
      end
    end

    context 'when payment has no source' do
      let(:payment) { double(source: nil, order: order) }

      it 'returns nil' do
        expect(gateway.create_profile(payment)).to be_nil
      end
    end

    context 'when payment source is not a PayPal source' do
      let(:payment_source) { create(:credit_card, payment_method: gateway) }

      it 'returns nil' do
        expect(gateway.create_profile(payment)).to be_nil
      end
    end

    context 'when account_id is blank' do
      let(:payment_source) do
        SpreePaypalCheckout::PaymentSources::Paypal.create!(
          payment_method: gateway,
          account_id: nil
        )
      end

      it 'returns nil' do
        expect(gateway.create_profile(payment)).to be_nil
      end
    end
  end

  describe '#client' do
    it 'returns a PayPal SDK client' do
      expect(gateway.client).to be_a(PaypalServerSdk::Client)
    end
  end

  describe '#authorize' do
    it 'raises Not implemented' do
      expect { gateway.authorize(1000, double) }.to raise_error('Not implemented')
    end
  end

  describe '#purchase' do
    let(:payment_source) { double(paypal_id: 'PAYPAL-ORDER-123') }

    it 'delegates to capture with the paypal_id' do
      expect(gateway).to receive(:capture).with(1000, 'PAYPAL-ORDER-123', {})
      gateway.purchase(1000, payment_source)
    end
  end

  describe '#capture' do
    let(:order) { create(:order, store: store) }
    let(:gateway_options) { { order_id: "#{order.number}-123" } }
    let(:paypal_id) { 'PAYPAL-ORDER-123' }

    context 'when capture is successful' do
      let(:response_data) { double(status: 'COMPLETED', id: paypal_id, as_json: { 'id' => paypal_id }) }
      let(:response) { double(data: response_data) }

      before do
        orders_api = double
        allow(gateway).to receive(:client).and_return(double(orders: orders_api))
        allow(orders_api).to receive(:capture_order).with({
          'id' => paypal_id,
          'prefer' => 'return=representation'
        }).and_return(response)
      end

      it 'returns a successful billing response' do
        result = gateway.capture(1000, paypal_id, gateway_options)

        expect(result).to be_a(SpreePaypalCheckout::Gateway::GatewayResponse)
        expect(result.success?).to be true
        expect(result.authorization).to eq(paypal_id)
      end
    end

    context 'when capture status is not COMPLETED' do
      let(:response_data) { double(status: 'PENDING', id: paypal_id, as_json: { 'id' => paypal_id }, with_indifferent_access: { 'id' => paypal_id }) }
      let(:response) { double(data: response_data) }

      before do
        orders_api = double
        allow(gateway).to receive(:client).and_return(double(orders: orders_api))
        allow(orders_api).to receive(:capture_order).and_return(response)
      end

      it 'returns a failure response' do
        result = gateway.capture(1000, paypal_id, gateway_options)

        expect(result).to be_a(SpreePaypalCheckout::Gateway::GatewayResponse)
        expect(result.success?).to be false
        expect(result.message).to eq('Failed to capture PayPal payment')
      end
    end

    context 'when order is not found' do
      it 'returns a failure response' do
        result = gateway.capture(1000, paypal_id, { order_id: 'NONEXISTENT-123' })

        expect(result).to be_a(SpreePaypalCheckout::Gateway::GatewayResponse)
        expect(result.success?).to be false
        expect(result.message).to eq('Order not found')
      end
    end

    context 'when PayPal API raises an error' do
      before do
        orders_api = double
        allow(gateway).to receive(:client).and_return(double(orders: orders_api))
        allow(orders_api).to receive(:capture_order).and_raise(
          PaypalServerSdk::APIException.new('The specified resource does not exist.', double(status_code: 404))
        )
      end

      it 'raises a GatewayError' do
        expect {
          gateway.capture(1000, paypal_id, gateway_options)
        }.to raise_error(Spree::Core::GatewayError, /PayPal API error/)
      end
    end
  end

  describe '#void' do
    let(:authorization) { 'AUTH-123' }
    let(:response_data) { double(as_json: { 'id' => authorization }) }
    let(:response) { double(data: response_data) }

    before do
      payments_api = double
      allow(gateway).to receive(:client).and_return(double(payments: payments_api))
      allow(payments_api).to receive(:void_payment).with({
        'authorization_id' => authorization,
        'prefer' => 'return=representation'
      }).and_return(response)
    end

    it 'returns a successful billing response' do
      result = gateway.void(authorization, nil)

      expect(result).to be_a(SpreePaypalCheckout::Gateway::GatewayResponse)
      expect(result.success?).to be true
      expect(result.authorization).to eq(authorization)
    end

    context 'when PayPal API raises an error' do
      before do
        payments_api = double
        allow(gateway).to receive(:client).and_return(double(payments: payments_api))
        allow(payments_api).to receive(:void_payment).and_raise(
          PaypalServerSdk::APIException.new('Void failed', double(status_code: 422))
        )
      end

      it 'raises a GatewayError' do
        expect {
          gateway.void(authorization, nil)
        }.to raise_error(Spree::Core::GatewayError, /PayPal API error/)
      end
    end
  end

  describe '#credit' do
    let(:order) { create(:order, store: store, currency: 'USD') }
    let(:refund) { double(order: order) }
    let(:gateway_options) { { originator: refund } }
    let(:capture_id) { 'CAPTURE-123' }
    let(:refund_id) { 'REFUND-456' }
    let(:response_data) { double(id: refund_id, as_json: { 'id' => refund_id }) }
    let(:response) { double(data: response_data) }

    before do
      payments_api = double
      allow(gateway).to receive(:client).and_return(double(payments: payments_api))
      allow(payments_api).to receive(:refund_captured_payment).with({
        'capture_id' => capture_id,
        'amount' => {
          'value' => '10.0',
          'currency_code' => 'USD'
        }
      }).and_return(response)
    end

    it 'returns a successful billing response with the refund ID' do
      result = gateway.credit(1000, nil, capture_id, gateway_options)

      expect(result).to be_a(SpreePaypalCheckout::Gateway::GatewayResponse)
      expect(result.success?).to be true
      expect(result.authorization).to eq(refund_id)
    end

    context 'when originator does not respond to order' do
      let(:gateway_options) { { originator: order } }

      it 'uses the originator as the order' do
        result = gateway.credit(1000, nil, capture_id, gateway_options)

        expect(result.success?).to be true
      end
    end

    context 'when order is not found' do
      let(:gateway_options) { { originator: nil } }

      it 'returns a failure response' do
        result = gateway.credit(1000, nil, capture_id, gateway_options)

        expect(result.success?).to be false
        expect(result.message).to eq('Order not found')
      end
    end

    context 'when PayPal API raises an error' do
      before do
        payments_api = double
        allow(gateway).to receive(:client).and_return(double(payments: payments_api))
        allow(payments_api).to receive(:refund_captured_payment).and_raise(
          PaypalServerSdk::APIException.new('Refund failed', double(status_code: 422))
        )
      end

      it 'raises a GatewayError' do
        expect {
          gateway.credit(1000, nil, capture_id, gateway_options)
        }.to raise_error(Spree::Core::GatewayError, /PayPal API error/)
      end
    end
  end

  describe '#cancel' do
    let(:authorization) { 'AUTH-123' }

    context 'when payment is completed' do
      let(:order) { create(:order, store: store) }
      let(:payment) do
        double(
          completed?: true,
          credit_allowed: 50.0,
          response_code: 'RESPONSE-123',
          order: order,
          refunds: double
        )
      end

      context 'when credit_allowed is zero' do
        before { allow(payment).to receive(:credit_allowed).and_return(0) }

        it 'returns a successful response without creating a refund' do
          result = gateway.cancel(authorization, payment)

          expect(result.success?).to be true
          expect(result.authorization).to eq(authorization)
        end
      end

      context 'when credit_allowed is positive' do
        let(:refund_reason) { create(:refund_reason, name: Spree::RefundReason::ORDER_CANCELED_REASON) }
        let(:refund_response) { double(params: { 'id' => 'REFUND-789' }) }
        let(:refund) { double(response: refund_response) }

        before do
          allow(Spree::RefundReason).to receive(:order_canceled_reason).and_return(refund_reason)
          allow(payment.refunds).to receive(:create!).with(
            amount: 50.0,
            reason: refund_reason,
            refunder_id: nil
          ).and_return(refund)
        end

        it 'creates a refund and returns a successful response' do
          result = gateway.cancel(authorization, payment)

          expect(result.success?).to be true
          expect(result.authorization).to eq('RESPONSE-123')
        end
      end
    end

    context 'when payment is not completed' do
      let(:payment) { double(completed?: false) }
      let(:response_data) { double(as_json: { 'id' => authorization }) }
      let(:response) { double(data: response_data) }

      before do
        payments_api = double
        allow(gateway).to receive(:client).and_return(double(payments: payments_api))
        allow(payments_api).to receive(:void_payment).with({
          'authorization_id' => authorization,
          'prefer' => 'return=representation'
        }).and_return(response)
      end

      it 'voids the payment via PayPal API' do
        result = gateway.cancel(authorization, payment)

        expect(result.success?).to be true
        expect(result.authorization).to eq(authorization)
      end
    end

    context 'when payment is nil' do
      let(:response_data) { double(as_json: { 'id' => authorization }) }
      let(:response) { double(data: response_data) }

      before do
        payments_api = double
        allow(gateway).to receive(:client).and_return(double(payments: payments_api))
        allow(payments_api).to receive(:void_payment).and_return(response)
      end

      it 'voids the payment via PayPal API' do
        result = gateway.cancel(authorization, nil)

        expect(result.success?).to be true
      end
    end
  end
end
