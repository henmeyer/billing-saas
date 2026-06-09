require "rails_helper"

RSpec.describe Imports::PreviewService do
  let(:account) { create(:account) }
  let(:user)    { create(:user) }
  let(:gateway) { create(:payment_gateway, account: account, provider: "asaas") }

  before { set_tenant(account) }

  let(:import_job) do
    ImportJob.create!(account: account, user: user, gateway: "asaas")
  end

  let(:asaas_customers) do
    [
      { gateway_id: "cus_1", name: "Novo Cliente",
        email: "novo@teste.com", document: nil,
        phone: nil, external_ref: nil, subscription: nil },
      { gateway_id: "cus_2", name: "Cliente Existente",
        email: "existente@teste.com", document: nil,
        phone: nil, external_ref: nil, subscription: nil }
    ]
  end

  before do
    gateway
    create(:customer, account: account, email: "existente@teste.com")
    allow_any_instance_of(Imports::FetchAsaasService)
      .to receive(:call).and_return(asaas_customers)
  end

  it "separa novos de duplicatas" do
    described_class.call(import_job)
    import_job.reload

    expect(import_job.status).to eq("preview_ready")
    expect(import_job.total_new).to eq(1)
    expect(import_job.total_duplicates).to eq(1)
    expect(import_job.preview["new"].first["email"]).to eq("novo@teste.com")
    expect(import_job.preview["duplicates"].first["email"]).to eq("existente@teste.com")
  end

  it "marca como failed em caso de erro" do
    allow_any_instance_of(Imports::FetchAsaasService)
      .to receive(:call).and_raise("API indisponível")

    expect { described_class.call(import_job) }.to raise_error("API indisponível")
    expect(import_job.reload.status).to eq("failed")
    expect(import_job.error_message).to eq("API indisponível")
  end
end
