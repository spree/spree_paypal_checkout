require 'spec_helper'

RSpec.describe SpreePaypalCheckout::CreateSource do
  let(:store) { create(:store) }
  let(:gateway) { create(:paypal_checkout_gateway, stores: [store]) }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }

  let(:paypal_payment_source) do
    {
      'paypal' => {
        'email_address' => 'sb-fxqy4743082799@personal.example.com',
        'account_id' => 'RX8ZD67CZ67RU',
        'account_status' => 'VERIFIED',
        'name' => {
          'given_name' => 'John',
          'surname' => 'Doe'
        }
      }
    }
  end

  describe '#call' do
    subject { described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: order).call }

    it 'creates a PayPal payment source' do
      expect { subject }.to change(SpreePaypalCheckout::PaymentSources::Paypal, :count).by(1)
    end

    it 'sets the correct attributes' do
      source = subject
      expect(source.email).to eq('sb-fxqy4743082799@personal.example.com')
      expect(source.account_id).to eq('RX8ZD67CZ67RU')
      expect(source.account_status).to eq('VERIFIED')
      expect(source.name).to eq('John Doe')
      expect(source.user).to eq(user)
      expect(source.payment_method).to eq(gateway)
      expect(source.gateway_payment_profile_id).to eq('RX8ZD67CZ67RU')
    end

    it 'reuses existing source for the same PayPal account and gateway' do
      described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: order).call
      expect { subject }.not_to change(SpreePaypalCheckout::PaymentSources::Paypal, :count)
    end

    context 'when guest checks out then signs in' do
      let(:guest_order) { create(:order_with_line_items, store: store, user: nil) }

      it 'does not raise a uniqueness violation' do
        # Guest checkout - source created without user
        described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: guest_order).call

        # Same PayPal account, now with a signed-in user
        expect {
          described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: order, user: user).call
        }.not_to raise_error
      end

      it 'associates the user to the existing source' do
        source = described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: guest_order).call
        expect(source.user).to be_nil

        source = described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: order, user: user).call
        expect(source.user).to eq(user)
      end

      it 'reuses the same source record' do
        guest_source = described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: guest_order).call
        user_source = described_class.new(paypal_payment_source: paypal_payment_source, gateway: gateway, order: order, user: user).call

        expect(user_source.id).to eq(guest_source.id)
      end
    end
  end
end
