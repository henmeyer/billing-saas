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

  describe "#initials" do
    it "retorna as duas primeiras iniciais do nome em maiúsculo" do
      expect(build(:user, name: "John Doe").initials).to eq("JD")
    end

    it "retorna apenas uma inicial quando o nome tem uma palavra" do
      expect(build(:user, name: "John").initials).to eq("J")
    end
  end

  describe "#avatar_url" do
    it "retorna nil quando não há avatar anexado" do
      expect(build(:user).avatar_url).to be_nil
    end

    it "retorna a url quando há avatar anexado" do
      user = create(:user)
      user.avatar.attach(io: StringIO.new("fake-image"), filename: "avatar.png", content_type: "image/png")

      expect(user.avatar_url).to include("avatar.png")
    end
  end

  describe "validação de avatar" do
    let(:user) { create(:user) }

    it "rejeita tipo de arquivo não permitido" do
      user.avatar.attach(io: StringIO.new("fake-pdf"), filename: "doc.pdf", content_type: "application/pdf")

      expect(user).not_to be_valid
      expect(user.errors[:avatar]).to include("deve ser JPEG, PNG ou WebP")
    end

    it "rejeita arquivos maiores que 5MB" do
      user.avatar.attach(
        io:           StringIO.new("a" * (6 * 1024 * 1024)),
        filename:     "avatar.png",
        content_type: "image/png"
      )

      expect(user).not_to be_valid
      expect(user.errors[:avatar]).to include("deve ter no máximo 5MB")
    end

    it "aceita JPEG, PNG ou WebP até 5MB" do
      user.avatar.attach(io: StringIO.new("fake-image"), filename: "avatar.png", content_type: "image/png")

      expect(user).to be_valid
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
