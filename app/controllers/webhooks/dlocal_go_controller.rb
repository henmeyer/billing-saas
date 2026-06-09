class Webhooks::DlocalGoController < Webhooks::BaseController
  before_action :authenticate_and_set_tenant

  def receive
    payload = JSON.parse(request.body.read)
    event   = payload["type"] || payload["event"]

    case event
    when "SUBSCRIPTION_ACTIVE"
      Webhooks::ProcessDlocalGoEventJob.perform_later("subscription_activated", payload)
    when "SUBSCRIPTION_CANCELLED"
      Webhooks::ProcessDlocalGoEventJob.perform_later("subscription_cancelled", payload)
    when "PAYMENT_PAID", "SUBSCRIPTION_RENEWAL_SUCCESS"
      Webhooks::ProcessDlocalGoEventJob.perform_later("payment_received", payload)
    when "PAYMENT_REJECTED", "PAYMENT_FAILED", "PAYMENT_EXPIRED"
      Webhooks::ProcessDlocalGoEventJob.perform_later("payment_failed", payload)
    end

    head :ok
  end

  private

  # dLocal Go assina com HMAC-SHA256 no header X-dLocalGo-Signature.
  # Identifica o tenant via PaymentGateway de provider dlocal_go.
  def authenticate_and_set_tenant
    signature = request.headers["X-dLocalGo-Signature"]
    body      = request.body.read
    request.body.rewind

    gateway = PaymentGateway.find_by(provider: "dlocal_go")

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
