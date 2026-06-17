require "rails_helper"

RSpec.describe Imports::ExecuteService do
  let(:account) { create(:account) }
  let(:user)    { create(:user) }
  let(:plan)    { create(:plan, account: account) }

  before { set_tenant(account) }

  let(:existing_customer) { create(:customer, account: account, email: "dup@teste.com") }

  let(:import_job) do
    ImportJob.create!(
      account:   account,
      user:      user,
      gateway:   "asaas",
      status:    "preview_ready",
      preview:   {
        "new"        => [{
          "gateway_id"   => "cus_new",
          "name"         => "Novo Cliente",
          "email"        => "novo@teste.com",
          "document"     => nil,
          "phone"        => nil,
          "external_ref" => nil,
          "subscription" => nil
        }],
        "duplicates" => [{
          "gateway_id"   => "cus_dup",
          "name"         => "Duplicado",
          "email"        => "dup@teste.com",
          "existing_id"  => existing_customer.id,
          "subscription" => nil
        }]
      },
      decisions: { "dup@teste.com" => "skip" }
    )
  end

  it "importa novos e processa duplicatas conforme decisão" do
    described_class.call(import_job)
    import_job.reload

    expect(import_job.status).to eq("done")
    expect(import_job.result["imported"]).to eq(1)
    expect(import_job.result["skipped"]).to eq(1)
    expect(Customer.find_by(email: "novo@teste.com")).to be_present
  end

  it "atualiza duplicata quando decisão é update" do
    import_job.update!(decisions: { "dup@teste.com" => "update" })
    described_class.call(import_job)

    expect(import_job.reload.result["updated"]).to eq(1)
    expect(existing_customer.reload.gateway_data.dig("asaas", "customer_id")).to eq("cus_dup")
  end

  it "registra erro ao tentar criar duplicata com email já existente" do
    import_job.update!(decisions: { "dup@teste.com" => "create" })
    described_class.call(import_job)

    result = import_job.reload.result
    expect(result["imported"]).to eq(1)
    expect(result["errors"]).not_to be_empty
    expect(result["errors"].first["email"]).to eq("dup@teste.com")
  end

  it "marca como failed em caso de erro inesperado" do
    allow(Customer).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
    described_class.call(import_job)

    expect(import_job.reload.result["errors"]).not_to be_empty
  end
end
