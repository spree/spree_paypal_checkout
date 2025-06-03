describe SpreePaypalCheckout::Order do
  let(:store) { create(:store) }
  let(:gateway) { create(:paypal_checkout_gateway, stores: [store]) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:paypal_checkout_order) { create(:paypal_checkout_order, order: order, payment_method: gateway) }

  describe '#paypal_payment_id' do
    context 'when order is not captured' do
      it 'returns nil' do
        expect(paypal_checkout_order.paypal_payment_id).to be_nil
      end
    end

    context 'when order is captured' do
      let(:paypal_checkout_order) { create(:captured_paypal_checkout_order, order: order, payment_method: gateway, amount: order.total) }

      it 'returns the PayPal payment ID' do
        expect(paypal_checkout_order.paypal_payment_id).to be_present
        expect(paypal_checkout_order.paypal_payment_id).to eq('6F473251BB811841E')
      end
    end
  end

  describe '#create_payment!' do
    subject { paypal_checkout_order.create_payment! }

    context 'when order is not captured' do
      it 'does not create a payment record' do
        expect { subject }.to raise_error(SpreePaypalCheckout::Order::NotCapturedError)
      end
    end

    context 'when order is captured' do
      let(:paypal_checkout_order) { create(:captured_paypal_checkout_order, order: order, payment_method: gateway, amount: order.total) }
      let(:payment) { Spree::Payment.last }

      it 'creates a payment record' do
        expect { subject }.to change(Spree::Payment, :count).by(1)
        expect(payment.response_code).to eq('6F473251BB811841E')
        expect(payment.state).to eq('completed')
        expect(payment.source).to be_present
        expect(payment.payment_method).to eq(gateway)
        expect(payment.order).to eq(order)
        expect(payment.amount).to eq(order.total)
        expect(payment.source.gateway_customer_profile_id).to eq('RX8ZD67CZ67RU')
        expect(payment.source.gateway_payment_profile_id).to eq('RX8ZD67CZ67RU')
        expect(payment.source.class).to eq(SpreePaypalCheckout::PaymentSources::Paypal)
      end
    end
  end
end
