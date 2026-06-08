require "rails_helper"

RSpec.describe User, type: :model do
  it { should have_many(:account_users) }
  it { should have_many(:accounts).through(:account_users) }
  it { should validate_presence_of(:name) }

  describe "#superadmin?" do
    it "retorna false para usuário comum" do
      expect(build(:user).superadmin?).to be false
    end
  end

  describe "#role_for" do
    let(:account) { create(:account) }
    let(:user)    { create(:user) }

    it "retorna o role do usuário na conta" do
      create(:account_user, account: account, user: user, role: "admin")
      expect(user.role_for(account)).to eq("admin")
    end

    it "retorna nil se o usuário não pertence à conta" do
      expect(user.role_for(account)).to be_nil
    end
  end
end

RSpec.describe SuperAdmin, type: :model do
  describe "#superadmin?" do
    it "retorna true" do
      expect(build(:super_admin).superadmin?).to be true
    end
  end
end
