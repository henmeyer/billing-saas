require "rails_helper"

RSpec.describe "Webhooks::Stripe", type: :request do
  describe "POST /webhooks/stripe" do
    context "com assinatura Stripe inválida" do
      it "retorna 401" do
        post "/webhooks/stripe",
             params:  { type: "invoice.payment_succeeded" }.to_json,
             headers: {
               "Content-Type"     => "application/json",
               "Stripe-Signature" => "t=123,v1=invalida"
             }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "com assinatura Stripe válida" do
      let(:payload_hash) do
        { "type" => "invoice.payment_succeeded", "data" => { "object" => { "subscription" => "sub_123" } } }
      end

      it "enfileira o job e retorna 200" do
        secret    = "whsec_test"
        timestamp = Time.now.to_i
        body      = payload_hash.to_json
        signed    = "#{timestamp}.#{body}"
        sig       = OpenSSL::HMAC.hexdigest("SHA256", secret, signed)
        sig_header = "t=#{timestamp},v1=#{sig}"

        stub_const("ENV", ENV.to_hash.merge("STRIPE_WEBHOOK_SECRET" => secret))

        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          double(
            type: "invoice.payment_succeeded",
            data: double(object: double(to_h: payload_hash["data"]["object"]))
          )
        )

        expect(Webhooks::ProcessStripeEventJob).to receive(:perform_later)
          .with("payment_received", anything)

        post "/webhooks/stripe",
             params:  body,
             headers: {
               "Content-Type"     => "application/json",
               "Stripe-Signature" => sig_header
             }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
