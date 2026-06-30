require "rails_helper"
require "inertia_rails/rspec"

RSpec.describe "Portal::Products", type: :request do
  let(:account)     { create(:account) }
  let(:credit_type) { create(:credit_type, account: account) }
  let(:integration) do
    create(:integration, account: account,
                         portal_config: { "allow_buy_products" => true })
  end
  let(:other_integration) { create(:integration, account: account) }
  let(:customer) { create(:customer, account: account) }

  let(:raw_token) { "portal-token-abc" }

  before do
    ActsAsTenant.current_tenant = account
    create(:portal_session,
           customer:     customer,
           integration:  integration,
           token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  after { ActsAsTenant.current_tenant = nil }

  def link(product, integ)
    create(:product_integration, product: product, integration: integ)
  end

  describe "GET /portal/:token/products" do
    it "lista apenas produtos vinculados à integração atual" do
      linked = create(:product, :credit_pack, account: account, name: "Pacote Linked")
      link(linked, integration)

      other = create(:product, :credit_pack, account: account, name: "Pacote Other")
      link(other, other_integration)

      create(:product, :credit_pack, account: account, name: "Pacote Sem Vínculo")

      ActsAsTenant.with_tenant(nil) do
        get "/portal/#{raw_token}/products"
      end

      names = inertia.props[:products].map { |p| p[:name] }
      expect(names).to contain_exactly("Pacote Linked")
    end

    it "inclui credit_pack e one_time vinculados, marcando recorrência" do
      pack = create(:product, :credit_pack, account: account, name: "Pacote")
      link(pack, integration)

      avulso = create(:product, account: account, product_type: "one_time", name: "Avulso")
      link(avulso, integration)

      ActsAsTenant.with_tenant(nil) do
        get "/portal/#{raw_token}/products"
      end

      products = inertia.props[:products]
      pack_data   = products.find { |p| p[:name] == "Pacote" }
      avulso_data = products.find { |p| p[:name] == "Avulso" }

      expect(pack_data[:product_type]).to eq("credit_pack")
      expect(pack_data[:recurring]).to be true
      expect(avulso_data[:product_type]).to eq("one_time")
      expect(avulso_data[:recurring]).to be false
    end

    it "não lista produtos inativos" do
      inactive = create(:product, :credit_pack, account: account, name: "Inativo", active: false)
      link(inactive, integration)

      ActsAsTenant.with_tenant(nil) do
        get "/portal/#{raw_token}/products"
      end

      expect(inertia.props[:products]).to be_empty
    end
  end

  describe "POST /portal/:token/products" do
    let(:plan)    { create(:plan, account: account) }
    let!(:product) do
      p = create(:product, :credit_pack, account: account, pricing_model: "per_unit")
      create(:product_price, product: p, amount_cents: 5_000)
      p
    end

    let!(:subscription) do
      create(:subscription, :asaas,
             customer:     customer,
             plan:         plan,
             integration:  integration,
             status:       "active")
    end

    let(:adapter) { instance_double(Gateways::AsaasAdapter) }

    before do
      allow(Gateways::Base).to receive(:for).with("asaas").and_return(adapter)
      allow(adapter).to receive(:create_charge).and_return(
        { "id" => "pay_123", "redirect_url" => nil }
      )
    end

    it "repassa a quantidade ao CreateChargeService" do
      expect(Portal::CreateChargeService).to receive(:call)
        .with(hash_including(quantity: 3))
        .and_call_original

      ActsAsTenant.with_tenant(nil) do
        post "/portal/#{raw_token}/products", params: { product_id: product.id, quantity: 3 }
      end
    end

    it "normaliza quantidade inválida para 1" do
      expect(Portal::CreateChargeService).to receive(:call)
        .with(hash_including(quantity: 1))
        .and_call_original

      ActsAsTenant.with_tenant(nil) do
        post "/portal/#{raw_token}/products", params: { product_id: product.id, quantity: 0 }
      end
    end
  end
end
