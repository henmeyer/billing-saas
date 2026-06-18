class Integrations::WebhookTestsController < ApplicationController
  before_action :require_admin!
  before_action :set_integration

  skip_after_action :verify_policy_scoped, only: :logs

  def create
    event = params[:event]

    unless Integration::AVAILABLE_EVENTS.include?(event)
      render json: { error: "Evento inválido" }, status: :unprocessable_entity
      return
    end

    result = Webhooks::TestService.call(integration: @integration, event: event)

    render json: {
      success:       result.success?,
      status_code:   result.status_code,
      response_body: result.response_body,
      duration_ms:   result.duration_ms,
      error:         result.error
    }
  end

  def logs
    logs = @integration.webhook_logs
                       .where(is_test: true)
                       .order(created_at: :desc)
                       .limit(10)
                       .map { |l| serialize_log(l) }

    render json: { logs: }
  end

  private

  def set_integration
    @integration = Integration.find(params[:integration_id])
    authorize @integration, :show?
  end

  def serialize_log(log)
    {
      id:            log.id,
      event:         log.event,
      status:        log.status,
      status_code:   log.response_code,
      response_body: log.response_body,
      duration_ms:   log.duration_ms,
      created_at:    log.created_at.strftime("%d/%m/%Y %H:%M:%S")
    }
  end
end
