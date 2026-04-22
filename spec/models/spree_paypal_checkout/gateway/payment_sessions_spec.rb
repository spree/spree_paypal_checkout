require 'spec_helper'

RSpec.describe SpreePaypalCheckout::Gateway::PaymentSessions do
  let(:store) { create(:store) }
  let(:gateway) { create(:paypal_checkout_gateway, stores: [store]) }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment') }

  describe '#session_required?' do
    it 'returns true by default' do
      expect(gateway.session_required?).to be true
    end

    it 'returns false when use_legacy_api is true' do
      allow(SpreePaypalCheckout::Config).to receive(:[]).with(:use_legacy_api).and_return(true)
      expect(gateway.session_required?).to be false
    end
  end

  describe '#payment_session_class' do
    it 'returns Spree::PaymentSessions::PaypalCheckout' do
      expect(gateway.payment_session_class).to eq(Spree::PaymentSessions::PaypalCheckout)
    end
  end

  describe '#create_payment_session' do
    let(:paypal_order_id) { '9DP54594E6135602P' }
    let(:paypal_response_data) do
      double(
        id: paypal_order_id,
        as_json: JSON.parse(File.read(SpreePaypalCheckout::Engine.root.join('spec', 'fixtures', 'paypal_order.json')))
      )
    end
    let(:paypal_response) { double(data: paypal_response_data) }

    before do
      orders_api = double
      allow(gateway).to receive(:client).and_return(double(orders: orders_api))
      allow(orders_api).to receive(:create_order).and_return(paypal_response)
    end

    it 'creates a payment session record' do
      expect {
        gateway.create_payment_session(order: order)
      }.to change(Spree::PaymentSessions::PaypalCheckout, :count).by(1)
    end

    it 'returns the payment session with correct attributes' do
      session = gateway.create_payment_session(order: order)

      expect(session).to be_a(Spree::PaymentSessions::PaypalCheckout)
      expect(session.external_id).to eq(paypal_order_id)
      expect(session.amount).to eq(order.total)
      expect(session.currency).to eq(order.currency)
      expect(session.status).to eq('pending')
      expect(session.order).to eq(order)
      expect(session.payment_method).to eq(gateway)
    end

    context 'when amount is zero' do
      it 'returns nil' do
        expect(gateway.create_payment_session(order: order, amount: 0)).to be_nil
      end
    end
  end

  describe '#update_payment_session' do
    let(:payment_session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway) }

    it 'updates the amount' do
      gateway.update_payment_session(payment_session: payment_session, amount: 99.99)
      expect(payment_session.reload.amount).to eq(99.99)
    end

    it 'merges external_data' do
      gateway.update_payment_session(payment_session: payment_session, external_data: { 'foo' => 'bar' })
      expect(payment_session.reload.external_data).to include('foo' => 'bar')
    end
  end

  describe '#complete_payment_session' do
    let(:payment_session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway) }
    let(:captured_data) { JSON.parse(File.read(SpreePaypalCheckout::Engine.root.join('spec', 'fixtures', 'captured_paypal_order.json'))) }
    let(:response_data) { double(status: 'COMPLETED', as_json: captured_data) }
    let(:response) { double(data: response_data) }

    before do
      orders_api = double
      allow(gateway).to receive(:client).and_return(double(orders: orders_api))
      allow(orders_api).to receive(:capture_order).and_return(response)
    end

    it 'creates a payment and marks session completed' do
      expect {
        gateway.complete_payment_session(payment_session: payment_session)
      }.to change(Spree::Payment, :count).by(1)

      expect(payment_session.reload.status).to eq('completed')
    end

    it 'creates a payment with the capture ID as response_code' do
      gateway.complete_payment_session(payment_session: payment_session)
      payment = order.payments.last
      expect(payment.response_code).to eq('6F473251BB811841E')
      expect(payment.source).to be_a(SpreePaypalCheckout::PaymentSources::Paypal)
    end

    context 'when capture status is not COMPLETED' do
      let(:response_data) { double(status: 'PENDING', as_json: { 'status' => 'PENDING' }) }

      it 'marks the session as failed' do
        gateway.complete_payment_session(payment_session: payment_session)
        expect(payment_session.reload.status).to eq('failed')
      end
    end

    context 'when PayPal API raises an error' do
      before do
        orders_api = double
        allow(gateway).to receive(:client).and_return(double(orders: orders_api))
        allow(orders_api).to receive(:capture_order).and_raise(
          PaypalServerSdk::APIException.new('Capture failed', double(status_code: 422))
        )
      end

      it 'marks the session as failed and raises GatewayError' do
        expect {
          gateway.complete_payment_session(payment_session: payment_session)
        }.to raise_error(Spree::Core::GatewayError, /PayPal API error/)

        expect(payment_session.reload.status).to eq('failed')
      end
    end
  end

  describe '#parse_webhook_event' do
    let(:payment_session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway, external_id: 'ORDER-123') }

    before do
      payment_session
      gateway.update!(preferences: gateway.preferences.merge(webhook_secret: nil))
    end

    context 'when event is CHECKOUT.ORDER.APPROVED' do
      let(:raw_body) { { event_type: 'CHECKOUT.ORDER.APPROVED', resource: { 'id' => 'ORDER-123' } }.to_json }

      it 'returns authorized action with payment session' do
        result = gateway.parse_webhook_event(raw_body, {})
        expect(result[:action]).to eq(:authorized)
        expect(result[:payment_session]).to eq(payment_session)
      end
    end

    context 'when event is PAYMENT.CAPTURE.COMPLETED' do
      let(:raw_body) do
        { event_type: 'PAYMENT.CAPTURE.COMPLETED',
          resource: { 'id' => 'CAPTURE-456', 'supplementary_data' => { 'related_ids' => { 'order_id' => 'ORDER-123' } } } }.to_json
      end

      it 'returns captured action with payment session' do
        result = gateway.parse_webhook_event(raw_body, {})
        expect(result[:action]).to eq(:captured)
        expect(result[:payment_session]).to eq(payment_session)
      end
    end

    context 'when payment session is not found' do
      let(:raw_body) { { event_type: 'CHECKOUT.ORDER.APPROVED', resource: { 'id' => 'UNKNOWN' } }.to_json }

      it 'returns nil' do
        expect(gateway.parse_webhook_event(raw_body, {})).to be_nil
      end
    end

    context 'when event type is unsupported' do
      let(:raw_body) { { event_type: 'BILLING.SUBSCRIPTION.CREATED', resource: { 'id' => 'ORDER-123' } }.to_json }

      it 'returns nil' do
        expect(gateway.parse_webhook_event(raw_body, {})).to be_nil
      end
    end
  end
end
