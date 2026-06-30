require "rails_helper"

RSpec.describe Product, type: :model do
  let(:account)     { create(:account) }
  let(:credit_type) { create(:credit_type, account: account) }

  before { ActsAsTenant.current_tenant = account }
  after  { ActsAsTenant.current_tenant = nil }

  describe "validações por tipo" do
    it "aceita one_time sem tipo de crédito (crédito opcional)" do
      product = build(:product, account: account, product_type: "one_time",
                                credit_type: nil, credit_quantity: 0)
      expect(product).to be_valid
    end

    it "aceita one_time com tipo de crédito" do
      product = build(:product, account: account, product_type: "one_time",
                                credit_type: credit_type, credit_quantity: 500)
      expect(product).to be_valid
    end

    it "rejeita credit_pack sem tipo de crédito" do
      product = build(:product, account: account, product_type: "credit_pack",
                                credit_type: nil, credit_quantity: 1000)
      expect(product).not_to be_valid
      expect(product.errors[:credit_type_id]).to be_present
    end

    it "rejeita credit_pack com quantidade zero" do
      product = build(:product, account: account, product_type: "credit_pack",
                                credit_type: credit_type, credit_quantity: 0)
      expect(product).not_to be_valid
      expect(product.errors[:credit_quantity]).to be_present
    end

    it "aceita credit_pack com tipo e quantidade" do
      product = build(:product, :credit_pack, account: account)
      expect(product).to be_valid
    end
  end

  describe "#grants_credit?" do
    it "é true quando há tipo de crédito e quantidade positiva" do
      product = build(:product, account: account, credit_type: credit_type, credit_quantity: 100)
      expect(product.grants_credit?).to be true
    end

    it "é false sem tipo de crédito" do
      product = build(:product, account: account, credit_type: nil, credit_quantity: 100)
      expect(product.grants_credit?).to be false
    end

    it "é false com quantidade zero" do
      product = build(:product, account: account, credit_type: credit_type, credit_quantity: 0)
      expect(product.grants_credit?).to be false
    end
  end

  describe "predicados de tipo" do
    it "#credit_pack? e #one_time?" do
      expect(build(:product, :credit_pack, account: account).credit_pack?).to be true
      expect(build(:product, account: account, product_type: "one_time").one_time?).to be true
    end
  end
end
