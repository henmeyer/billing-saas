# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "subscriptions:migrate_asaas" do
  let(:account)     { create(:account) }
  let(:customer)    { create(:customer, account: account, gateway_data: { "asaas" => { "customer_id" => "cus_test" } }) }
  let(:plan)        { create(:plan, account: account) }
  let(:integration) { create(:integration, account: account) }

  before do
    set_tenant(account)
    create(:payment_gateway, account: account, provider: "asaas")

    Rails.application.load_tasks unless Rake::Task.task_defined?("subscriptions:migrate_asaas")

    stub_request(:delete, /asaas\.com\/.*\/subscriptions/)
      .to_return(status: 200, body: { "deleted" => true }.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "migrate_asaas" do
    let!(:gateway_sub) do
      create(:subscription, :asaas, :gateway_managed,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             status:                  "active",
             gateway_subscription_id: "sub_asaas_native_999")
    end

    it "migra subscription de gateway-managed para billing-managed" do
      expect { Rake::Task["subscriptions:migrate_asaas"].invoke }
        .to output(/1 migradas/).to_stdout

      gateway_sub.reload
      expect(gateway_sub.managed_by).to eq("billing")
      expect(gateway_sub.metadata["migrated_from_gateway"]).to be true
      expect(gateway_sub.metadata["migrated_at"]).to be_present
      expect(gateway_sub.metadata["original_asaas_sub_id"]).to eq("sub_asaas_native_999")
    ensure
      Rake::Task["subscriptions:migrate_asaas"].reenable
    end

    it "cancela a subscription nativa no Asaas" do
      Rake::Task["subscriptions:migrate_asaas"].invoke

      expect(a_request(:delete, /subscriptions\/sub_asaas_native_999/)).to have_been_made.once
    ensure
      Rake::Task["subscriptions:migrate_asaas"].reenable
    end

    it "não migra subscriptions billing-managed" do
      gateway_sub.update!(managed_by: "billing")

      expect { Rake::Task["subscriptions:migrate_asaas"].invoke }
        .to output(/0 migradas/).to_stdout
    ensure
      Rake::Task["subscriptions:migrate_asaas"].reenable
    end

    it "não migra subscriptions canceladas" do
      gateway_sub.update!(status: "cancelled", cancelled_at: Time.current)

      expect { Rake::Task["subscriptions:migrate_asaas"].invoke }
        .to output(/0 migradas/).to_stdout
    ensure
      Rake::Task["subscriptions:migrate_asaas"].reenable
    end
  end

  describe "list_asaas_gateway" do
    let!(:gateway_sub) do
      create(:subscription, :asaas, :gateway_managed,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             status:                  "active",
             gateway_subscription_id: "sub_asaas_list_123")
    end

    it "lists gateway-managed subscriptions" do
      expect { Rake::Task["subscriptions:list_asaas_gateway"].invoke }
        .to output(/1 subscriptions gateway-managed/).to_stdout
    ensure
      Rake::Task["subscriptions:list_asaas_gateway"].reenable
    end
  end
end
