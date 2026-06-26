require "rails_helper"

RSpec.describe Gateways::ResolverService do
  let(:account) { create(:account) }

  before { set_tenant(account) }

  context "com Asaas e Stripe ativos" do
    before do
      create(:payment_gateway, account: account, provider: "asaas")
      create(:payment_gateway, account: account, provider: "stripe")
    end

    it "resolve Asaas para Brasil" do
      result = described_class.call(account: account, country: "BR")
      expect(result).to eq("asaas")
    end

    it "resolve Stripe para EUA" do
      result = described_class.call(account: account, country: "US")
      expect(result).to eq("stripe")
    end
  end

  context "com dLocal Go e Stripe ativos" do
    before do
      create(:payment_gateway, account: account, provider: "dlocal_go")
      create(:payment_gateway, account: account, provider: "stripe")
    end

    it "resolve dLocal Go para Argentina" do
      result = described_class.call(account: account, country: "AR")
      expect(result).to eq("dlocal_go")
    end

    it "resolve dLocal Go para Brasil (sem Asaas)" do
      result = described_class.call(account: account, country: "BR")
      expect(result).to eq("dlocal_go")
    end

    it "resolve Stripe para Japão" do
      result = described_class.call(account: account, country: "JP")
      expect(result).to eq("stripe")
    end
  end

  context "com Asaas e Stripe ativos (sem dLocal Go)" do
    before do
      create(:payment_gateway, account: account, provider: "asaas")
      create(:payment_gateway, account: account, provider: "stripe")
    end

    it "resolve Asaas para LATAM como fallback" do
      result = described_class.call(account: account, country: "AR")
      expect(result).to eq("asaas")
    end

    it "resolve Stripe para países fora de LATAM" do
      result = described_class.call(account: account, country: "DE")
      expect(result).to eq("stripe")
    end
  end

  context "com todos os gateways ativos" do
    before do
      create(:payment_gateway, account: account, provider: "asaas")
      create(:payment_gateway, account: account, provider: "dlocal_go")
      create(:payment_gateway, account: account, provider: "stripe")
    end

    it "resolve Asaas para Brasil" do
      result = described_class.call(account: account, country: "BR")
      expect(result).to eq("asaas")
    end

    it "resolve dLocal Go para LATAM (não BR)" do
      result = described_class.call(account: account, country: "MX")
      expect(result).to eq("dlocal_go")
    end

    it "resolve Stripe para países fora de LATAM" do
      result = described_class.call(account: account, country: "US")
      expect(result).to eq("stripe")
    end
  end

  context "sem gateways ativos" do
    it "retorna nil" do
      result = described_class.call(account: account, country: "BR")
      expect(result).to be_nil
    end
  end

  context "gateway inativo" do
    it "não considera gateway inativo" do
      create(:payment_gateway, account: account, provider: "asaas", active: false)
      result = described_class.call(account: account, country: "BR")
      expect(result).to be_nil
    end
  end

  describe ".payment_methods_for" do
    it "inclui Pix e Boleto para Asaas" do
      methods = described_class.payment_methods_for(provider: "asaas", country: "BR")
      expect(methods.map { |m| m[:id] }).to include("PIX", "BOLETO", "CREDIT_CARD")
    end

    it "inclui Pix e Boleto para dLocal Go no Brasil" do
      methods = described_class.payment_methods_for(provider: "dlocal_go", country: "BR")
      expect(methods.map { |m| m[:id] }).to include("PIX", "BOLETO", "CARD")
    end

    it "inclui transferência bancária para dLocal Go na Argentina" do
      methods = described_class.payment_methods_for(provider: "dlocal_go", country: "AR")
      expect(methods.map { |m| m[:id] }).to include("BANK_TRANSFER")
    end

    it "retorna apenas cartão para Stripe" do
      methods = described_class.payment_methods_for(provider: "stripe", country: "US")
      expect(methods.map { |m| m[:id] }).to eq(["CARD"])
    end
  end
end
