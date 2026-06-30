require "rails_helper"

RSpec.describe Charge, type: :model do
  let(:account) { create(:account) }

  before { ActsAsTenant.current_tenant = account }
  after  { ActsAsTenant.current_tenant = nil }

  it "aceita o charge_type plan_change" do
    customer = create(:customer, account: account)
    sub      = create(:subscription, customer: customer, integration: create(:integration, account: account))
    charge   = build(:charge, customer: customer, subscription: sub, charge_type: "plan_change")
    expect(charge).to be_valid
  end

  it "rejeita charge_type desconhecido" do
    customer = create(:customer, account: account)
    sub      = create(:subscription, customer: customer, integration: create(:integration, account: account))
    charge   = build(:charge, customer: customer, subscription: sub, charge_type: "unknown")
    expect(charge).not_to be_valid
    expect(charge.errors[:charge_type]).to be_present
  end
end
