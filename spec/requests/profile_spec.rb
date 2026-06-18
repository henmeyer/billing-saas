require "rails_helper"
require "inertia_rails/rspec"

RSpec.describe "Profile", type: :request do
  let(:account) { create(:account) }
  let(:user)    { create(:user, name: "John Doe", password: "password123") }

  before do
    create(:account_user, account: account, user: user, role: "admin")
    sign_in user
    set_tenant(account)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe "GET /profile" do
    it "renderiza Profile/Show com os dados do usuário" do
      get profile_path

      expect(inertia).to render_component("Profile/Show")
      expect(inertia.props[:user][:name]).to eq("John Doe")
      expect(inertia.props[:user][:initials]).to eq("JD")
      expect(inertia.props[:user][:avatar_url]).to be_nil
    end
  end

  describe "PUT /profile" do
    it "atualiza o nome" do
      put profile_path, params: { name: "Novo Nome" }

      expect(response).to redirect_to(profile_path)
      expect(user.reload.name).to eq("Novo Nome")
    end

    it "anexa o avatar enviado" do
      file = fixture_file_upload(Rails.root.join("spec/fixtures/files/avatar.png"), "image/png")

      put profile_path, params: { name: user.name, avatar: file }

      expect(user.reload.avatar).to be_attached
    end

    context "alterando a senha" do
      it "exige a senha atual correta" do
        put profile_path, params: {
          section:               "password",
          current_password:      "wrong",
          password:              "newpassword123",
          password_confirmation: "newpassword123"
        }

        follow_redirect!
        expect(response.body).to include("Senha atual incorreta") if response.body.present?
        expect(user.reload.valid_password?("newpassword123")).to be false
      end

      it "altera a senha com sucesso e mantém o usuário autenticado" do
        put profile_path, params: {
          section:               "password",
          current_password:      "password123",
          password:              "newpassword123",
          password_confirmation: "newpassword123"
        }

        expect(response).to redirect_to(profile_path)
        expect(user.reload.valid_password?("newpassword123")).to be true
      end

      it "rejeita confirmação que não confere" do
        put profile_path, params: {
          section:               "password",
          current_password:      "password123",
          password:              "newpassword123",
          password_confirmation: "different"
        }

        expect(user.reload.valid_password?("newpassword123")).to be false
      end
    end
  end

  describe "DELETE /profile/destroy_avatar" do
    it "remove o avatar do usuário" do
      user.avatar.attach(io: StringIO.new("fake-image"), filename: "avatar.png", content_type: "image/png")

      delete destroy_avatar_profile_path

      expect(response).to redirect_to(profile_path)
      expect(user.reload.avatar).not_to be_attached
    end
  end
end
