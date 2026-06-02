class Webhooks::OmnichannelController < Webhooks::BaseController
  before_action :set_account_from_token

  def receive
    return unless verify_hmac_signature(ENV.fetch("OMNICHANNEL_WEBHOOK_SECRET"))

    payload = JSON.parse(request.body.read)

    case payload["event"]
    when "credits_consumed"
      Webhooks::SyncCreditsJob.perform_later(payload)
    when "licenses_updated"
      Webhooks::SyncLicensesJob.perform_later(payload)
    end

    head :ok
  end

  private

  def set_account_from_token
    token   = request.headers["X-Account-Token"]
    api_key = ApiKey.without_tenant { ApiKey.find_by_token(token) }

    unless api_key&.active?
      render json: { error: "Token inválido" }, status: :unauthorized
      return
    end

    ActsAsTenant.current_tenant = api_key.account
  end
end
