require "rails_helper"

RSpec.describe WebhookDispatchJob do
  let(:account)  { create(:account) }
  let(:customer) { create(:customer, account: account) }

  before { set_tenant(account) }
  after  { ActsAsTenant.current_tenant = nil }

  let!(:integration) do
    create(:integration,
           account: account,
           events:  ["payment.received"],
           url:     "https://example.com/hook")
  end

  # ---------------------------------------------------------------------------
  # Entrega e retry
  # ---------------------------------------------------------------------------

  describe "entrega com sucesso" do
    before do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: true, code: 200, body: "ok")
      )
    end

    it "cria um WebhookLog com status delivered" do
      described_class.perform_now(customer, "payment.received", {})
      log = WebhookLog.last
      expect(log.status).to eq("delivered")
      expect(log.event).to eq("payment.received")
    end

    it "envia o header X-Billing-Signature" do
      expect(HTTParty).to receive(:post).with(
        integration.url,
        hash_including(headers: hash_including("X-Billing-Signature" => /^sha256=/))
      ).and_return(double(success?: true))
      described_class.perform_now(customer, "payment.received", {})
    end
  end

  describe "quando o endpoint falha" do
    before do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: false, code: 500, body: "internal error")
      )
    end

    it "cria log com next_retry_at e enfileira retry" do
      described_class.perform_now(customer, "payment.received", {})
      log = WebhookLog.last
      expect(log.status).to eq("pending")
      expect(log.next_retry_at).to be_present
    end
  end

  describe "quando nenhuma integração cobre o evento" do
    it "não cria WebhookLog" do
      expect {
        described_class.perform_now(customer, "evento.desconhecido", {})
      }.not_to change(WebhookLog, :count)
    end
  end

  describe "após 5 tentativas falhas" do
    before do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: false, code: 503, body: "unavailable")
      )
    end

    it "marca o log como failed na última tentativa" do
      described_class.perform_now(customer, "payment.received", {}, attempt: 6)
      expect(WebhookLog.last.status).to eq("failed")
    end
  end

  # ---------------------------------------------------------------------------
  # Conteúdo do payload
  # ---------------------------------------------------------------------------

  describe "payload" do
    let(:plan) { create(:plan, account: account, billing_cycle: "monthly") }

    let(:subscription) do
      create(:subscription,
             customer:             customer,
             plan:                 plan,
             integration:          integration,
             gateway:              "dlocal_go",
             status:               "active",
             started_at:           1.month.ago,
             current_period_start: 1.day.ago,
             current_period_end:   29.days.from_now,
             base_price_cents:     19_700,
             currency_code:        "BRL")
    end

    let(:captured_payload) { {} }

    before do
      allow(HTTParty).to receive(:post) do |_url, opts|
        captured_payload.merge!(JSON.parse(opts[:body]))
        double(success?: true, code: 200, body: "ok")
      end
    end

    context "estrutura base" do
      before { subscription }

      it "inclui event, uuid, timestamp e account_id" do
        described_class.perform_now(customer, "payment.received", {})
        expect(captured_payload).to include(
          "event"      => "payment.received",
          "account_id" => customer.account_id.to_s,
          "uuid"       => be_present,
          "timestamp"  => be_present
        )
      end

      it "inclui dados do customer" do
        described_class.perform_now(customer, "payment.received", {})
        expect(captured_payload["customer"]).to include(
          "id"    => customer.id.to_s,
          "name"  => customer.name,
          "email" => customer.email
        )
      end

      it "não cria nesting billing dentro do payload" do
        described_class.perform_now(customer, "payment.received", {})
        expect(captured_payload).not_to have_key("billing")
      end

      it "repassa o data para o payload" do
        described_class.perform_now(customer, "payment.received",
                                    { charge_id: "pay_abc", amount_cents: 19_700 })
        expect(captured_payload["data"]).to include(
          "charge_id" => "pay_abc", "amount_cents" => 19_700
        )
      end
    end

    context "com subscription ativa vinculada à integração" do
      before { subscription }

      it "inclui dados da subscription" do
        described_class.perform_now(customer, "payment.received", {})
        sub_data = captured_payload["subscription"]
        expect(sub_data).to include(
          "id"               => subscription.id,
          "plan_id"          => plan.id,
          "plan_name"        => plan.name,
          "status"           => "active",
          "billing_cycle"    => "monthly",
          "base_price_cents" => 19_700,
          "currency_code"    => "BRL"
        )
        expect(sub_data["started_at"]).to be_present
        expect(sub_data["current_period_end"]).to be_present
      end
    end

    context "com features no plano" do
      before do
        ft1 = create(:feature_type, account: account, key: "ai_enabled")
        ft2 = create(:feature_type, account: account, key: "export_csv")
        plan.plan_features.create!(feature_type: ft1, enabled: true)
        plan.plan_features.create!(feature_type: ft2, enabled: false)
        subscription
      end

      it "inclui features como hash key → booleano" do
        described_class.perform_now(customer, "payment.received", {})
        expect(captured_payload["features"]).to include(
          "ai_enabled" => true,
          "export_csv" => false
        )
      end
    end

    context "com créditos no período" do
      let!(:credit_type) { create(:credit_type, account: account, key: "coins") }

      before do
        subscription
        period = create(:subscription_period,
                        subscription: subscription,
                        period_start: 1.day.ago,
                        period_end:   29.days.from_now)
        period.subscription_period_credits.create!(
          credit_type:    credit_type,
          quantity:       1000,
          base:           1000,
          extras:         0,
          extra_packages: 0
        )
        period.credit_snapshots.create!(
          credit_type:   credit_type,
          used:          200,
          limit:         1000,
          balance:       800,
          usage_percent: 20.0,
          synced_at:     Time.current
        )
      end

      it "inclui credits com dados do período e snapshot" do
        described_class.perform_now(customer, "payment.received", {})
        coins = captured_payload.dig("credits", "coins")
        expect(coins).to include(
          "limit"         => 1000,
          "base"          => 1000,
          "used"          => 200,
          "balance"       => 800,
          "usage_percent" => 20.0
        )
      end
    end

    context "com licenças no período" do
      let!(:license_type) { create(:license_type, account: account, key: "user_licenses") }

      before do
        subscription
        customer.update!(metadata: { "license_usage" => { "user_licenses" => 3 } })
        period = create(:subscription_period,
                        subscription: subscription,
                        period_start: 1.day.ago,
                        period_end:   29.days.from_now)
        period.subscription_period_licenses.create!(
          license_type: license_type,
          quantity:     10
        )
      end

      it "inclui licenses com alocado, usado e disponível" do
        described_class.perform_now(customer, "payment.received", {})
        ul = captured_payload.dig("licenses", "user_licenses")
        expect(ul).to include(
          "allocated" => 10,
          "used"      => 3,
          "available" => 7,
          "unlimited" => false
        )
      end
    end

    context "com license ilimitada (quantity = 0)" do
      let!(:license_type) { create(:license_type, account: account, key: "inboxes") }

      before do
        subscription
        period = create(:subscription_period,
                        subscription: subscription,
                        period_start: 1.day.ago,
                        period_end:   29.days.from_now)
        period.subscription_period_licenses.create!(
          license_type: license_type,
          quantity:     0
        )
      end

      it "marca unlimited true e allocated/available como nil" do
        described_class.perform_now(customer, "payment.received", {})
        inbox = captured_payload.dig("licenses", "inboxes")
        expect(inbox).to include(
          "allocated" => nil,
          "available" => nil,
          "unlimited" => true
        )
      end
    end

    context "external_id via customer_identity" do
      before do
        subscription
        create(:customer_identity,
               customer:    customer,
               integration: integration,
               external_id: "EXT_ABC123")
      end

      it "usa o external_id da integração específica" do
        described_class.perform_now(customer, "payment.received", {})
        expect(captured_payload.dig("customer", "external_id")).to eq("EXT_ABC123")
      end
    end

    context "sem subscription vinculada à integração" do
      it "subscription é nil e features/credits/licenses são hashes vazios" do
        described_class.perform_now(customer, "payment.received", {})
        expect(captured_payload["subscription"]).to be_nil
        expect(captured_payload["features"]).to eq({})
        expect(captured_payload["credits"]).to eq({})
        expect(captured_payload["licenses"]).to eq({})
      end
    end

    context "subscription de outra integração não contamina o payload" do
      # other_integration NÃO assina "payment.received" — job só despacha para integration
      let(:other_integration) do
        create(:integration, account: account, events: ["subscription.activated"])
      end

      before do
        create(:subscription,
               customer:    customer,
               plan:        plan,
               integration: other_integration,
               gateway:     "stripe",
               status:      "active",
               started_at:  1.month.ago)
      end

      it "subscription é nil para a integração correta" do
        described_class.perform_now(customer, "payment.received", {})
        expect(captured_payload["subscription"]).to be_nil
      end
    end
  end
end
