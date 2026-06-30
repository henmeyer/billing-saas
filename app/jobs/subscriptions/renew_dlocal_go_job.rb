# frozen_string_literal: true

class Subscriptions::RenewDlocalGoJob < ApplicationJob
  queue_as :billing

  # Rodar diariamente via cron (06:00 UTC).
  # Cria um novo checkout (payment) para cada assinatura vencendo.
  # O cliente recebe o link de pagamento e pode pagar via Pix, cartão, boleto, etc.
  # Quando o webhook confirmar o pagamento, o período é renovado.
  def perform
    Subscription.where(status: %w[active past_due])
                .where(gateway: "dlocal_go")
                .where("current_period_end <= ?", Time.current.end_of_day)
                .includes(:customer, :plan, :currency)
                .find_each do |subscription|
      renew(subscription)
    rescue Gateways::Base::GatewayError => e
      handle_gateway_error(subscription, e)
    rescue StandardError => e
      Rails.logger.error(
        "[RenewDlocalGo] Erro ao renovar sub #{subscription.id}: #{e.message}"
      )
    end
  end

  private

  def renew(subscription)
    ActsAsTenant.current_tenant = subscription.customer.account
    apply_scheduled_plan_change!(subscription)

    customer       = subscription.customer
    extra_packages = subscription.metadata["extra_packages"] || {}
    product_packs  = subscription.metadata["product_packs"] || {}
    currency       = subscription.effective_currency

    pricing = Pricing::CalculateService.call(
      plan:           subscription.plan,
      customer:       customer,
      currency:       currency,
      extra_packages: extra_packages,
      product_packs:  product_packs
    )

    # Cria checkout normal — cliente vai receber link para pagar
    adapter = Gateways::DlocalGoAdapter.new
    result  = adapter.create_charge(
      customer,
      pricing.amount_cents,
      currency:    currency.code,
      country:     customer.gateway_data.dig("dlocal_go", "country") || "BR",
      prefix:      "renew",
      description: "#{subscription.plan.name} — Renovação"
    )

    # Salva charge pendente (webhook vai confirmar)
    subscription.charges.create!(
      customer:          customer,
      gateway:           "dlocal_go",
      gateway_charge_id: result["id"],
      amount_cents:      pricing.amount_cents,
      status:            "pending",
      redirect_url:      result["redirect_url"],
      charge_type:       "renewal",
      charge_data:       {
        "order_id" => result["order_id"],
        "renewal"  => true
      }
    )

    # TODO: Enviar link de pagamento ao cliente (email/webhook)
    # Por enquanto, dispara webhook para o sistema externo lidar
    WebhookDispatchJob.perform_later(
      customer,
      "subscription.renewal_pending",
      {
        gateway:      "dlocal_go",
        redirect_url: result["redirect_url"],
        amount_cents: pricing.amount_cents,
        due_date:     subscription.current_period_end.to_s
      }
    )

    Rails.logger.info(
      "[RenewDlocalGo] Payment criado para sub #{subscription.id}: " \
      "#{result["id"]} — #{currency.code} #{pricing.amount_cents / 100.0}"
    )
  end

  # Aplica troca de plano agendada (downgrade) antes de renovar, para que a
  # renovação já use o novo plano e valor. Limpa o agendamento após aplicar.
  def apply_scheduled_plan_change!(subscription)
    scheduled = subscription.metadata["scheduled_plan_change"]
    return if scheduled.blank?

    new_plan = Plan.find_by(id: scheduled["plan_id"])
    if new_plan && new_plan.id != subscription.plan_id
      subscription.change_plan!(new_plan, changed_by: subscription.customer, reason: "scheduled_downgrade")
    end

    subscription.update!(metadata: subscription.metadata.except("scheduled_plan_change"))
  end

  def handle_gateway_error(subscription, error)
    Rails.logger.error(
      "[RenewDlocalGo] Gateway error sub #{subscription.id}: #{error.message}"
    )

    subscription.update!(status: "past_due")

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "payment.failed",
      { gateway: "dlocal_go", reason: error.message }
    )
  end
end
