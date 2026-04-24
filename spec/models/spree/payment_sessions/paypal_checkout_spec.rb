require 'spec_helper'

RSpec.describe Spree::PaymentSessions::PaypalCheckout do
  let(:store) { create(:store) }
  let(:gateway) { create(:paypal_checkout_gateway, stores: [store]) }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:captured_data) { JSON.parse(File.read(SpreePaypalCheckout::Engine.root.join('spec', 'fixtures', 'captured_paypal_order.json'))) }

  describe '#paypal_order_id' do
    let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway, external_id: 'ORDER-123') }

    it 'returns the external_id' do
      expect(session.paypal_order_id).to eq('ORDER-123')
    end
  end

  describe '#paypal_capture_id' do
    context 'when order is captured' do
      let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway, external_data: captured_data) }

      it 'returns the capture ID from external_data' do
        expect(session.paypal_capture_id).to eq('6F473251BB811841E')
      end
    end

    context 'when order is not captured' do
      let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway) }

      it 'returns nil' do
        expect(session.paypal_capture_id).to be_nil
      end
    end
  end

  describe '#accepted?' do
    context 'when status is COMPLETED' do
      let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway, external_data: captured_data) }

      it 'returns true' do
        expect(session.accepted?).to be true
      end
    end

    context 'when status is not COMPLETED' do
      let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway) }

      it 'returns false' do
        expect(session.accepted?).to be false
      end
    end
  end

  describe '#find_or_create_payment!' do
    let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway, external_data: captured_data) }

    it 'creates a Spree::Payment record' do
      expect { session.find_or_create_payment! }.to change(Spree::Payment, :count).by(1)
    end

    it 'sets the response_code to the capture ID' do
      payment = session.find_or_create_payment!
      expect(payment.response_code).to eq('6F473251BB811841E')
    end

    it 'creates a PayPal payment source' do
      payment = session.find_or_create_payment!
      expect(payment.source).to be_a(SpreePaypalCheckout::PaymentSources::Paypal)
      expect(payment.source.email).to eq('sb-fxqy4743082799@personal.example.com')
      expect(payment.source.account_id).to eq('RX8ZD67CZ67RU')
    end

    it 'does not create duplicate payments' do
      session.find_or_create_payment!
      expect { session.find_or_create_payment! }.not_to change(Spree::Payment, :count)
    end

    context 'when guest checks out then signs in (user changes)' do
      let(:guest_order) { create(:order_with_line_items, store: store, user: nil) }
      let(:session) { create(:paypal_checkout_payment_session, order: guest_order, payment_method: gateway, external_data: captured_data) }

      it 'creates a payment source without a user' do
        payment = session.find_or_create_payment!
        expect(payment.source).to be_a(SpreePaypalCheckout::PaymentSources::Paypal)
        expect(payment.source.user).to be_nil
      end

      it 'reuses the same payment source when user is later associated' do
        # First checkout as guest
        payment = session.find_or_create_payment!
        source = payment.source

        # Simulate guest signing in - order now has a user
        guest_order.update!(user: user)

        # New session for a second order by the now-signed-in user
        second_order = create(:order_with_line_items, store: store, user: user)
        second_session = create(:paypal_checkout_payment_session, order: second_order, payment_method: gateway, external_data: captured_data)

        second_payment = second_session.find_or_create_payment!
        expect(second_payment.source).to eq(source)
        expect(second_payment.source.user).to eq(user)
      end

      it 'does not raise a uniqueness violation when user changes' do
        # First checkout as guest
        session.find_or_create_payment!

        # Second checkout with a user using the same PayPal account
        user_order = create(:order_with_line_items, store: store, user: user)
        user_session = create(:paypal_checkout_payment_session, order: user_order, payment_method: gateway, external_data: captured_data)

        expect { user_session.find_or_create_payment! }.not_to raise_error
      end
    end

    context 'when payment_source data is not present' do
      let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway, external_data: captured_data.except('payment_source')) }

      it 'creates a payment without a source' do
        payment = session.find_or_create_payment!
        expect(payment).to be_present
        expect(payment.source).to be_nil
      end
    end

    context 'when capture has not happened yet' do
      let(:session) { create(:paypal_checkout_payment_session, order: order, payment_method: gateway) }

      it 'returns nil' do
        expect(session.find_or_create_payment!).to be_nil
      end
    end
  end
end
