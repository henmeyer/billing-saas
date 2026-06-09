class ImportsController < ApplicationController
  before_action :require_admin!
  before_action :set_import_job, only: [:show, :decide, :execute]

  def index
    import_jobs = ImportJob.recent.limit(10)
    render inertia: "Imports/Index", props: {
      import_jobs: import_jobs.map { |j| serialize(j) },
      gateways:    available_gateways
    }
  end

  def create
    gateway = params[:gateway]
    unless PaymentGateway.active.exists?(provider: gateway)
      redirect_to imports_path, alert: "Gateway #{gateway} não configurado."
      return
    end

    import_job = ImportJob.create!(
      account: current_account,
      user:    current_user,
      gateway: gateway,
      status:  "pending"
    )

    Imports::FetchPreviewJob.perform_later(import_job.id)

    redirect_to import_path(import_job),
                notice: "Buscando clientes do #{gateway}..."
  end

  def show
    render inertia: "Imports/Show", props: {
      import_job: serialize_full(@import_job)
    }
  end

  def decide
    unless @import_job.preview_ready?
      redirect_to import_path(@import_job), alert: "Import não está pronto."
      return
    end

    @import_job.update!(decisions: params[:decisions] || {})
    render json: { status: "ok" }
  end

  def execute
    unless @import_job.preview_ready?
      redirect_to import_path(@import_job), alert: "Import não está pronto."
      return
    end

    Imports::ExecuteJob.perform_later(@import_job.id)
    render json: { status: "importing" }
  end

  private

  def set_import_job
    @import_job = ImportJob.find(params[:id])
  end

  def serialize(j)
    {
      id:               j.id,
      gateway:          j.gateway,
      status:           j.status,
      total_preview:    j.total_preview,
      total_new:        j.total_new,
      total_duplicates: j.total_duplicates,
      result:           j.result,
      error_message:    j.error_message,
      created_at:       j.created_at.strftime("%d/%m/%Y %H:%M")
    }
  end

  def serialize_full(j)
    serialize(j).merge(
      preview:   j.preview,
      decisions: j.decisions
    )
  end

  def available_gateways
    PaymentGateway.active.pluck(:provider)
  end
end
