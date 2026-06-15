class Integrations::WebhookLogsController < ApplicationController
  before_action :require_admin!
  before_action :set_integration

  def index
    logs = @integration.webhook_logs
                       .order(created_at: :desc)
                       .limit(50)
                       .includes(:customer)
                       .map { |l| serialize(l) }

    render json: { logs: }
  end

  private

  def set_integration
    @integration = Integration.find(params[:integration_id])
  end

  def serialize(log)
    {
      id:            log.id,
      event:         log.event,
      status:        log.status,
      is_test:       log.is_test,
      status_code:   log.response_code,
      response_body: log.response_body&.truncate(200),
      duration_ms:   log.duration_ms,
      attempts:      log.attempts,
      customer_name: log.customer&.name,
      created_at:    log.created_at.strftime("%d/%m/%Y %H:%M:%S")
    }
  end
end
