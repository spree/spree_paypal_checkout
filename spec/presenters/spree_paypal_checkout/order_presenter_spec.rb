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
        expect(subject.to_json['body'].purchase_units[0].items.first.name).to be_nil.or eq("")
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
end