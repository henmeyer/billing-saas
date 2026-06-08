require "rails_helper"

RSpec.describe CreditSnapshot, type: :model do
  let(:account) { create(:account) }

  before { set_tenant(account) }

  describe "cálculo automático" do
    let(:subscription)  { create(:subscription, customer: create(:customer, account: account), plan: create(:plan, account: account)) }
    let(:period)        { create(:subscription_period, subscription: subscription) }
    let(:credit_type)   { create(:credit_type, account: account) }

    it "calcula balance e usage_percent antes de salvar" do
      snapshot = CreditSnapshot.create!(
        subscription_period: period,
        credit_type:         credit_type,
        used:                300,
        limit:               1000,
        synced_at:           Time.current
      )
      expect(snapshot.balance).to eq(700)
      expect(snapshot.usage_percent).to eq(30.0)
    end

    it "não permite balance negativo" do
      snapshot = CreditSnapshot.create!(
        subscription_period: period,
        credit_type:         credit_type,
        used:                1200,
        limit:               1000,
        synced_at:           Time.current
      )
      expect(snapshot.balance).to eq(0)
    end
  end
end
