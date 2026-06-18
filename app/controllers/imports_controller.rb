class ImportsController < ApplicationController
  before_action :require_admin!
  before_action :set_import_job, only: [:show, :decide, :execute]

  def index
    import_jobs = policy_scope(ImportJob).recent.limit(10)
    render inertia: "Imports/Index", props: {
      import_jobs: import_jobs.map { |j| serialize(j) },
      gateways:    available_gateways
    }
  end

  def create
    authorize ImportJob

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
    authorize @import_job

    render inertia: "Imports/Show", props: {
      import_job:   serialize_full(@import_job),
      integrations: Integration.active.map { |i| { id: i.id, name: i.name } }
    }
  end

  def decide
    authorize @import_job

    unless @import_job.preview_ready?
      redirect_to import_path(@import_job), alert: "Import não está pronto."
      return
    end

    @import_job.update!(
      decisions:  params[:decisions]  || {},
      identities: params[:identities] || {}
    )
    render json: { status: "ok" }
  end

  def execute
    authorize @import_job

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

  def serialize(job)
    {
      id:               job.id,
      gateway:          job.gateway,
      status:           job.status,
      total_preview:    job.total_preview,
      total_new:        job.total_new,
      total_duplicates: job.total_duplicates,
      result:           job.result,
      error_message:    job.error_message,
      created_at:       job.created_at.strftime("%d/%m/%Y %H:%M")
    }
  end

  def serialize_full(job)
    serialize(job).merge(
      preview:    job.preview,
      decisions:  job.decisions,
      identities: job.identities
    )
  end

  def available_gateways
    PaymentGateway.active.pluck(:provider)
  end
end
