class Webhooks::AsaasController < Webhooks::BaseController
  def receive
    return unless verify_static_token(
      ENV.fetch("ASAAS_WEBHOOK_SECRET"),
      header_name: "asaas-access-token"
    )

    payload = JSON.parse(request.body.read)
    event   = payload["event"]

    case event
    when "PAYMENT_RECEIVED", "PAYMENT_CONFIRMED"
      Webhooks::ProcessAsaasEventJob.perform_later("payment_received", payload)
    when "PAYMENT_OVERDUE"
      Webhooks::ProcessAsaasEventJob.perform_later("payment_overdue", payload)
    when "PAYMENT_DELETED", "PAYMENT_REFUNDED"
      Webhooks::ProcessAsaasEventJob.perform_later("payment_refunded", payload)
    when "SUBSCRIPTION_DELETED"
      Webhooks::ProcessAsaasEventJob.perform_later("subscription_cancelled", payload)
    end

    head :ok
  end
end
