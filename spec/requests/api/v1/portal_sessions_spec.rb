require "rails_helper"

RSpec.describe "Api::V1::PortalSessions", type: :request do
  let(:account)     { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:customer)    { create(:customer, account: account) }

  let(:raw_token) do
    _key, token = IntegrationApiKey.generate!(integration: integration, name: "test")
    token
  end

  before do
    set_tenant(account)
    customer.set_identity!(integration: integration, external_id: "EXT123")
  end

  after { ActsAsTenant.current_tenant = nil }

  let(:headers) { { "Authorization" => "Bearer #{raw_token}" } }

  describe "POST /api/v1/portal/sessions" do
    it "creates a portal session and returns a magic link" do
      post "/api/v1/portal/sessions",
           params:  { external_id: "EXT123" },
           headers: headers

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["url"]).to include("/portal/")
      expect(json["expires_in"]).to eq(900)
      expect(json["expires_at"]).to be_present
    end

    it "returns 404 if customer not found" do
      post "/api/v1/portal/sessions",
           params:  { external_id: "NONEXISTENT" },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authorization" do
      post "/api/v1/portal/sessions",
           params: { external_id: "EXT123" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
