require "rails_helper"

RSpec.describe Account, type: :model do
  it { should have_many(:users).through(:account_users) }
  it { should have_many(:plans) }
  it { should have_many(:customers) }
  it { should have_many(:license_types) }
  it { should have_many(:credit_types) }
  it { should have_many(:feature_types) }
  it { should have_many(:integrations) }
  it { should have_many(:api_keys) }
  it { should have_many(:currencies) }
  it { should validate_presence_of(:name) }

  describe "#generate_slug" do
    it "gera slug a partir do nome" do
      account = build(:account, name: "Minha Empresa", slug: nil)
      account.valid?
      expect(account.slug).to eq("minha-empresa")
    end
  end
end
