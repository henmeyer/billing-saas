require "rails_helper"

RSpec.describe ProductIntegration, type: :model do
  let(:account) { create(:account) }

  before { ActsAsTenant.current_tenant = account }
  after  { ActsAsTenant.current_tenant = nil }

  it "belongs to a product and an integration" do
    assoc = described_class.reflect_on_association(:product)
    expect(assoc.macro).to eq(:belongs_to)
    assoc = described_class.reflect_on_association(:integration)
    expect(assoc.macro).to eq(:belongs_to)
  end

  it "is valid with a product and integration" do
    pi = build(:product_integration,
               product:     create(:product, account: account),
               integration: create(:integration, account: account))
    expect(pi).to be_valid
  end

  it "does not allow the same product linked twice to the same integration" do
    product     = create(:product, account: account)
    integration = create(:integration, account: account)
    create(:product_integration, product: product, integration: integration)

    dup = build(:product_integration, product: product, integration: integration)
    expect(dup).not_to be_valid
  end

  it "links a product to many integrations" do
    product      = create(:product, account: account)
    integration1 = create(:integration, account: account)
    integration2 = create(:integration, account: account)

    create(:product_integration, product: product, integration: integration1)
    create(:product_integration, product: product, integration: integration2)

    expect(product.reload.integrations).to contain_exactly(integration1, integration2)
  end

  it "is destroyed when the product is destroyed" do
    product     = create(:product, account: account)
    integration = create(:integration, account: account)
    create(:product_integration, product: product, integration: integration)

    expect { product.destroy }.to change(described_class, :count).by(-1)
  end
end
