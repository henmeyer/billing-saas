require "rails_helper"

RSpec.describe Accounts::CreateService do
  let(:params) do
    {
      company_name:          "Empresa Teste",
      name:                  "João Silva",
      email:                 "joao@teste.com",
      password:              "password123",
      password_confirmation: "password123"
    }
  end

  it "cria account, user e account_user com role owner" do
    result = described_class.call(params)
    expect(result.success?).to be true
    expect(result.account.name).to eq("Empresa Teste")
    expect(result.user.email).to eq("joao@teste.com")
    expect(result.user.account_users.first.role).to eq("owner")
  end

  it "cria os tipos padrão na conta" do
    result = described_class.call(params)
    ActsAsTenant.with_tenant(result.account) do
      expect(LicenseType.count).to be > 0
      expect(CreditType.count).to be > 0
      expect(Currency.count).to be > 0
    end
  end

  it "retorna erro com email inválido" do
    result = described_class.call(params.merge(email: "invalido"))
    expect(result.success?).to be false
    expect(result.errors).not_to be_empty
  end

  it "faz rollback em caso de erro" do
    expect {
      described_class.call(params.merge(password_confirmation: "errada"))
    }.not_to change(Account, :count)
  end
end
