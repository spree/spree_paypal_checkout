RSpec.describe SpreePaypalCheckout::OrderPresenter do
  let(:order) { build_stubbed(:order, line_items: [line_item]) }
  subject { described_class.new(order) }

  context "line_item.name" do

    context "when line_item.name is longer than 127 characters" do
      let(:line_item) {
        item = build_stubbed(:line_item)
        allow(item).to receive(:name).and_return("A" * 200)
        item
      }

      it "truncates to 127 characters" do
        item = subject.to_json['body'].purchase_units[0].items.first
        expect(item.name.length).to eq(127)
      end
    end

    context "when line_item.name is exactly 127 characters" do
      let(:line_item) {
        item = build_stubbed(:line_item)
        allow(item).to receive(:name).and_return("B" * 127)
        item
      }
      it "does not truncate the name" do
        item = subject.to_json['body'].purchase_units[0].items.first
        expect(item.name).to eq("B" * 127)
      end
    end

    context "when line_item.name is nil" do
      let(:line_item) {
        item = build_stubbed(:line_item)
        allow(item).to receive(:name).and_return(nil)
        item
      }
      it "handles nil without raising" do
        expect { subject.to_json['body'].purchase_units[0].items.first }.not_to raise_error
        expect(subject.to_json['body'].purchase_units[0].items.first.name).to eq("")
      end
    end
  end

  context "discount" do
    let(:line_item) {
      item = build_stubbed(:line_item)
      allow(item).to receive(:name).and_return("B" * 127)
      item
    }
    it "should pass positive number to paypal for discount value" do
      allow(order).to receive(:promo_total).and_return(-100)
      expect(subject.to_json['body'].purchase_units[0].amount.breakdown.discount.value).to eq("100")
    end

    it "should be zero when discount is zero" do
      allow(order).to receive(:promo_total).and_return(0)
      expect(subject.to_json['body'].purchase_units[0].amount.breakdown.discount.value).to eq("0")
    end

    it "should be zero when discount is nil" do
      expect(subject.to_json['body'].purchase_units[0].amount.breakdown.discount.value).to eq("0.0")
    end
  end

  context "tax_total breakdown (PayPal AMOUNT_MISMATCH guard)" do
    let(:line_item) {
      item = build_stubbed(:line_item)
      allow(item).to receive(:name).and_return("Item")
      item
    }

    def breakdown
      subject.to_json['body'].purchase_units[0].amount.breakdown
    end

    # PayPal validates: amount.value == item_total + tax_total + shipping
    # - discount. The gross item_total/unit prices already carry any INCLUDED
    # (tax-inclusive / VAT) tax, so only ADDITIONAL tax may be added on top.
    context "tax-inclusive order (e.g. UK/EU VAT)" do
      before do
        allow(order).to receive(:item_total).and_return(120.0) # gross, VAT baked in
        allow(order).to receive(:included_tax_total).and_return(20.0)
        allow(order).to receive(:additional_tax_total).and_return(0.0)
        allow(order).to receive(:tax_total).and_return(20.0)    # included + additional
        allow(order).to receive(:ship_total).and_return(0.0)
        allow(order).to receive(:promo_total).and_return(0)
        allow(order).to receive(:total).and_return(120.0)       # gross total
      end

      it "sends only additional tax so it does not double-count included VAT" do
        expect(breakdown.tax_total.value).to eq("0.0")
      end

      it "reconciles value == item_total + tax_total + shipping - discount" do
        sum = breakdown.item_total.value.to_d + breakdown.tax_total.value.to_d +
              breakdown.shipping.value.to_d - breakdown.discount.value.to_d
        expect(sum).to eq(order.total.to_d)
      end
    end

    context "tax-exclusive order (e.g. US)" do
      before do
        allow(order).to receive(:item_total).and_return(100.0)
        allow(order).to receive(:included_tax_total).and_return(0.0)
        allow(order).to receive(:additional_tax_total).and_return(8.0)
        allow(order).to receive(:tax_total).and_return(8.0)
        allow(order).to receive(:ship_total).and_return(5.0)
        allow(order).to receive(:promo_total).and_return(0)
        allow(order).to receive(:total).and_return(113.0)
      end

      it "is unchanged: additional_tax_total == tax_total" do
        expect(breakdown.tax_total.value).to eq("8.0")
      end

      it "reconciles value == item_total + tax_total + shipping - discount" do
        sum = breakdown.item_total.value.to_d + breakdown.tax_total.value.to_d +
              breakdown.shipping.value.to_d - breakdown.discount.value.to_d
        expect(sum).to eq(order.total.to_d)
      end
    end
  end
end