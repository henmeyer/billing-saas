require "rails_helper"
require "inertia_rails/rspec"

RSpec.describe "Products", type: :request do
  let(:account)     { create(:account) }
  let(:user)        { create(:user) }
  let(:credit_type) { create(:credit_type, account: account) }

  before do
    create(:account_user, account: account, user: user, role: "admin")
    sign_in user
    set_tenant(account)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe "POST /products" do
    let(:integration_a) { create(:integration, account: account) }
    let(:integration_b) { create(:integration, account: account) }

    it "cria produto vinculando às integrações selecionadas" do
      post products_path, params: {
        product:         {
          name:            "Pacote 1000",
          product_type:    "credit_pack",
          credit_type_id:  credit_type.id,
          credit_quantity: 1000
        },
        integration_ids: [integration_a.id, integration_b.id]
      }

      ActsAsTenant.with_tenant(account) do
        product = Product.last
        expect(product.name).to eq("Pacote 1000")
        expect(product.integrations).to contain_exactly(integration_a, integration_b)
      end
    end

    it "cria one_time sem tipo de crédito" do
      post products_path, params: {
        product: { name: "Setup avulso", product_type: "one_time" }
      }

      ActsAsTenant.with_tenant(account) do
        product = Product.last
        expect(product.product_type).to eq("one_time")
        expect(product.credit_type_id).to be_nil
      end
    end
  end

  describe "PUT /products/:id" do
    let(:product)       { create(:product, :credit_pack, account: account) }
    let(:integration_a) { create(:integration, account: account) }
    let(:integration_b) { create(:integration, account: account) }

    before do
      create(:product_integration, product: product, integration: integration_a)
    end

    it "sincroniza os vínculos de integração (substitui os antigos)" do
      put product_path(product), params: {
        product:         { name: product.name },
        integration_ids: [integration_b.id]
      }

      ActsAsTenant.with_tenant(account) do
        expect(product.reload.integrations).to contain_exactly(integration_b)
      end
    end

    it "remove todos os vínculos quando integration_ids vem vazio" do
      put product_path(product), params: {
        product:         { name: product.name },
        integration_ids: []
      }

      ActsAsTenant.with_tenant(account) do
        expect(product.reload.integrations).to be_empty
      end
    end
  end

  describe "GET /products/:id/edit" do
    let(:product)     { create(:product, :credit_pack, account: account) }
    let(:integration) { create(:integration, account: account) }

    before do
      create(:product_integration, product: product, integration: integration)
    end

    it "serializa integration_ids e integrations disponíveis" do
      get edit_product_path(product)

      expect(inertia.props[:product][:integration_ids]).to eq([integration.id])
      expect(inertia.props[:integrations].map { |i| i[:id] }).to include(integration.id)
    end
  end
end
