# frozen_string_literal: true

class Webhooks::DlocalGoController < Webhooks::BaseController
  before_action :authenticate_and_set_tenant

  def receive
    payload = JSON.parse(request.body.read)
    request.body.rewind

    status = payload["status"] || payload["payment_status"]

    case status
    when "PAID", "COMPLETED", "APPROVED"
      Webhooks::ProcessDlocalGoEventJob.perform_later("payment_received", payload)
    when "REJECTED", "CANCELLED", "EXPIRED", "FAILED"
      Webhooks::ProcessDlocalGoEventJob.perform_later("payment_failed", payload)
    when "PENDING", "AUTHORIZED"
      Rails.logger.info("[dLocal Go] Payment #{payload["id"]} status: #{status}")
    end

    head :ok
  end

  private

  # Identifica o tenant pelo payment_id do payload.
  # Busca a charge que contém esse gateway_charge_id para descobrir a account.
  # Depois valida o HMAC com a secret_key do gateway daquela account.
  def authenticate_and_set_tenant
    body = request.body.read
    request.body.rewind

    payload    = JSON.parse(body) rescue {}
    payment_id = payload["id"] || payload["payment_id"]

    # Encontra a charge pelo ID do pagamento — sem tenant (multi-tenant)
    charge = ActsAsTenant.without_tenant do
      Charge.where(gateway: "dlocal_go")
            .find_by(gateway_charge_id: payment_id)
    end

    unless charge
      Rails.logger.warn("[dLocal Go] Webhook recebido para payment_id=#{payment_id} não encontrado")
      head :ok # Retorna 200 para não ficar em retry
      return
    end

    account = ActsAsTenant.without_tenant { charge.customer.account }
    ActsAsTenant.current_tenant = account

    # Valida HMAC se a signature estiver presente
    signature = request.headers["X-dLocalGo-Signature"]
    return unless signature.present?

    gateway  = account.payment_gateways.find_by(provider: "dlocal_go")
    expected = OpenSSL::HMAC.hexdigest("SHA256", gateway.secret_key, body)

    return if ActiveSupport::SecurityUtils.secure_compare(expected, signature)

    render json: { error: "Assinatura inválida" }, status: :unauthorized
  end
end
