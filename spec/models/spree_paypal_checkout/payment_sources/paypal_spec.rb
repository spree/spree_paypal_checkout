require 'spec_helper'

describe SpreePaypalCheckout::PaymentSources::Paypal do
  let(:gateway) { create(:paypal_checkout_gateway) }
  let(:other_gateway) { create(:paypal_checkout_gateway) }

  before { described_class.create!(payment_method: gateway, gateway_payment_profile_id: 'RX8ZD67CZ67RU') }

  describe 'gateway_payment_profile_id uniqueness' do
    it 'allows the same PayPal account under a different payment method' do
      source = described_class.new(payment_method: other_gateway, gateway_payment_profile_id: 'RX8ZD67CZ67RU')
      expect(source).to be_valid
    end

    it 'rejects the same PayPal account under the same payment method' do
      source = described_class.new(payment_method: gateway, gateway_payment_profile_id: 'RX8ZD67CZ67RU')
      expect(source).not_to be_valid
      expect(source.errors[:gateway_payment_profile_id]).to be_present
    end

    it 'does not change the uniqueness rule for other payment source types' do
      uniqueness = Spree::PaymentSource.validators_on(:gateway_payment_profile_id).grep(ActiveRecord::Validations::UniquenessValidator)
      expect(uniqueness.map { |validator| validator.options[:scope] }).to eq([:type])
    end
  end
end
