require "rails_helper"

RSpec.describe Currency, type: :model do
  let(:account) { create(:account) }

  before { set_tenant(account) }

  it { should validate_presence_of(:code) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:symbol) }

  describe "ensure_single_default" do
    it "remove padrão anterior quando define nova moeda padrão" do
      brl = create(:currency, account: account, code: "BRL", default: true)
      usd = create(:usd_currency, account: account, default: false)

      usd.update!(default: true)

      expect(brl.reload.default).to be false
      expect(usd.reload.default).to be true
    end
  end
end
