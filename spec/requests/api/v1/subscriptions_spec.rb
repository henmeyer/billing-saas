require "rails_helper"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  let(:account)  { create(:account) }
  let(:customer) { create(:customer, account: account, external_id: "EXT001") }
  let(:plan)     { create(:plan, account: account, name: "Pro", price_cents: 9900) }
  let!(:sub)     { create(:subscription, customer: customer, plan: plan) }
  let(:raw_token) { "billing_#{SecureRandom.hex(32)}" }
  let!(:api_key) do
    ActsAsTenant.with_tenant(account) do
      ApiKey.create!(
        name:         "test",
        token_digest: Digest::SHA256.hexdigest(raw_token),
        last_four:    raw_token.last(4),
        active:       true
      )
    end
  end

  let(:headers) { { "Authorization" => "Bearer #{raw_token}" } }

  describe "GET /api/v1/customers/:external_id/subscription" do
    it "retorna os dados da assinatura ativa" do
      get "/api/v1/customers/EXT001/subscription", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["plan"]["name"]).to eq("Pro")
      expect(json["plan"]["price_cents"]).to eq(9900)
      expect(json["status"]).to eq("active")
    end

    it "retorna 404 para cliente sem assinatura" do
      customer2 = create(:customer, account: account, external_id: "EXT002")
      get "/api/v1/customers/EXT002/subscription", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
