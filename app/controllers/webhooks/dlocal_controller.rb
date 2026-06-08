class Webhooks::DlocalController < Webhooks::BaseController
  before_action :authenticate_and_set_tenant

  def receive
    payload = JSON.parse(request.body.read)
    event   = payload["status"]

    case event
    when "PAID"
      Webhooks::ProcessDlocalEventJob.perform_later("payment_received", payload)
    when "REJECTED", "CANCELLED", "EXPIRED"
      Webhooks::ProcessDlocalEventJob.perform_later("payment_failed", payload)
    when "PENDING", "AUTHORIZED"
      Rails.logger.info("[dLocal] Payment #{payload['id']} status: #{event}")
    end

    head :ok
  end

  private

  # dLocal assina com HMAC-SHA256 no header X-Signature.
  # Identifica o tenant via X-Login que corresponde ao api_key do PaymentGateway.
  def authenticate_and_set_tenant
    signature = request.headers["X-Signature"]
    body      = request.body.read
    request.body.rewind

    gateway = PaymentGateway.find_by(provider: "dlocal")

    unless gateway
      render json: { error: "Gateway não configurado" }, status: :unauthorized
      return
    end

    ActsAsTenant.current_tenant = gateway.account
    expected = OpenSSL::HMAC.hexdigest("SHA256", gateway.secret_key, body)

    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      render json: { error: "Assinatura inválida" }, status: :unauthorized
    end
  end
end
