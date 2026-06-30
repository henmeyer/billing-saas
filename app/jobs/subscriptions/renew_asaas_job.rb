# frozen_string_literal: true

class Subscriptions::RenewAsaasJob < ApplicationJob
  queue_as :billing

  # Rodar diariamente via cron (06:00 UTC).
  # Cria cobrança avulsa no Asaas (POST /v3/payments) para cada assinatura
  # billing-managed vencendo hoje. Quando o webhook confirmar o pagamento,
  # o período é renovado pelo ProcessAsaasEventJob.
  def perform
    Subscription.where(status: %w[active past_due])
                .billing_managed
                .where(gateway: "asaas")
                .where("current_period_end <= ?", Time.current.end_of_day)
                .includes(:customer, :plan, :currency)
                .find_each do |subscription|
      renew(subscription)
    rescue Gateways::Base::GatewayError => e
      handle_gateway_error(subscription, e)
    rescue StandardError => e
      Rails.logger.error(
        "[RenewAsaas] Erro ao renovar sub #{subscription.id}: #{e.message}"
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

    # Cria cobrança avulsa no Asaas
    adapter = Gateways::AsaasAdapter.new
    result  = adapter.create_charge(
      customer,
      pricing.amount_cents,
      billing_type: determine_billing_type(subscription),
      description:  "#{subscription.plan.name} — Renovação",
      due_date:     Date.current.strftime("%Y-%m-%d")
    )

    # Salva charge pendente (webhook vai confirmar)
    subscription.charges.create!(
      customer:          customer,
      gateway:           "asaas",
      gateway_charge_id: result["id"],
      amount_cents:      pricing.amount_cents,
      status:            "pending",
      due_date:          Date.current,
      charge_type:       "renewal",
      charge_data:       {
        "renewal"      => true,
        "billing_type" => result["billingType"],
        "invoice_url"  => result["invoiceUrl"],
        "pix"          => result["pix"],
        "boleto"       => result["boleto"]
      }
    )

    # Dispara webhook para o sistema externo (link de pagamento)
    WebhookDispatchJob.perform_later(
      customer,
      "subscription.renewal_pending",
      {
        gateway:      "asaas",
        amount_cents: pricing.amount_cents,
        invoice_url:  result["invoiceUrl"],
        due_date:     Date.current.to_s
      }
    )

    Rails.logger.info(
      "[RenewAsaas] Cobrança #{result['id']} criada para sub #{subscription.id} — " \
      "#{currency.code} #{pricing.amount_cents / 100.0}"
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

  def determine_billing_type(subscription)
    # Usa o mesmo billing_type da última cobrança bem-sucedida
    last_charge = subscription.charges
                              .where(status: "paid", gateway: "asaas")
                              .order(paid_at: :desc)
                              .first
    last_charge&.charge_data&.dig("billing_type") || "UNDEFINED"
  end

  def handle_gateway_error(subscription, error)
    Rails.logger.error(
      "[RenewAsaas] Gateway error sub #{subscription.id}: #{error.message}"
    )

    subscription.update!(status: "past_due")

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "payment.failed",
      { gateway: "asaas", reason: error.message }
    )
  end
end
