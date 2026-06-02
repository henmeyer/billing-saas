class Webhooks::StripeController < Webhooks::BaseController
  def receive
    payload    = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

    begin
      event = Stripe::Webhook.construct_event(
        payload,
        sig_header,
        ENV.fetch("STRIPE_WEBHOOK_SECRET")
      )
    rescue Stripe::SignatureVerificationError
      render json: { error: "Assinatura inválida" }, status: :unauthorized
      return
    end

    case event.type
    when "invoice.payment_succeeded"
      Webhooks::ProcessStripeEventJob.perform_later("payment_received", event.data.object.to_h)
    when "invoice.payment_failed"
      Webhooks::ProcessStripeEventJob.perform_later("payment_failed", event.data.object.to_h)
    when "customer.subscription.deleted"
      Webhooks::ProcessStripeEventJob.perform_later("subscription_cancelled", event.data.object.to_h)
    when "customer.subscription.updated"
      Webhooks::ProcessStripeEventJob.perform_later("subscription_updated", event.data.object.to_h)
    end

    head :ok
  end
end
