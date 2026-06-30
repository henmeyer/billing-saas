# frozen_string_literal: true

class Webhooks::ProcessDlocalGoEventJob < ApplicationJob
  queue_as :webhooks

  def perform(event_type, payload)
    order_id   = payload["order_id"] || payload["external_id"] || ""
    payment_id = payload["id"]

    subscription = find_subscription(order_id, payment_id)

    case event_type
    when "payment_received"
      if subscription
        process_subscription_payment(subscription, payload, payment_id)
      else
        process_standalone_payment(payload, payment_id)
      end
    when "payment_failed"
      process_payment_failed(subscription, payload) if subscription
    end
  end

  private

  # Estratégia principal: a charge já foi criada pelo nosso sistema antes do
  # cliente pagar (CreateService, RenewDlocalGoJob, ConversionsController),
  # então ela já tem o subscription_id correto — não importa o prefixo do
  # order_id. Isso cobre qualquer fluxo (renovação, conversão de trial, etc).
  # Fallback: parse do order_id, para compatibilidade com fluxos antigos.
  def find_subscription(order_id, payment_id)
    charge = ActsAsTenant.without_tenant do
      Charge.where(gateway: "dlocal_go").find_by(gateway_charge_id: payment_id)
    end

    if charge
      ActsAsTenant.current_tenant = charge.customer.account
      return charge.subscription
    end

    find_subscription_by_order_id(order_id)
  end

  # Formatos: "sub_CUSTOMER_ID_TIMESTAMP" ou "renew_CUSTOMER_ID_TIMESTAMP"
  def find_subscription_by_order_id(order_id)
    return unless order_id.match?(/^(sub|renew)_\d+_/)

    customer_id = order_id.match(/^(?:sub|renew)_(\d+)_/)[1] rescue nil
    return unless customer_id

    customer = Customer.find_by(id: customer_id)
    return unless customer

    ActsAsTenant.current_tenant = customer.account

    customer.subscriptions
            .where(gateway: "dlocal_go")
            .where(status: %w[active trialing past_due pending])
            .order(created_at: :desc)
            .first
  end

  def process_subscription_payment(subscription, payload, payment_id)
    customer     = subscription.customer
    amount_cents = extract_amount(payload)

    # Idempotência: só ignora se essa charge já está confirmada como paga
    existing_charge = subscription.charges.find_by(gateway_charge_id: payment_id)
    return if existing_charge&.status == "paid"

    # Charges avulsas (produto/troca de plano) aplicam efeitos sem renovar.
    if existing_charge && (existing_charge.charge_type_product? || existing_charge.charge_type_plan_change?)
      existing_charge.update!(status: "paid", paid_at: Time.current)
      Charges::ApplyPaidChargeService.call(charge: existing_charge)
      WebhookDispatchJob.perform_later(
        customer, "payment.received",
        { amount_cents: existing_charge.amount_cents, gateway: "dlocal_go", charge_id: payment_id }
      )
      return
    end

    # Salva checkout_id para cobranças recorrentes futuras (crucial no primeiro pagamento)
    checkout_id = payload["id"] || payload["checkout_id"]
    if checkout_id.present?
      customer.gateway_data["dlocal_go"] ||= {}
      customer.gateway_data["dlocal_go"]["checkout_id"] = checkout_id
      customer.save!
    end

    was_pending  = subscription.status == "pending"
    was_trialing = subscription.trialing?
    period_start = Time.current.beginning_of_day
    period_end   = next_period(subscription)

    ActiveRecord::Base.transaction do
      # Atualiza charge pendente se existir, ou cria nova
      if existing_charge
        existing_charge.update!(status: "paid", paid_at: Time.current)
      else
        subscription.charges.create!(
          customer:          customer,
          gateway:           "dlocal_go",
          gateway_charge_id: payment_id,
          amount_cents:      amount_cents,
          status:            "paid",
          charge_type:       was_pending || was_trialing ? "new_subscription" : "renewal",
          paid_at:           Time.current
        )
      end

      if was_trialing
        # Conversão de trial: vira assinatura paga, mantém o período (e os
        # créditos/licenças já concedidos) e só atualiza valores e datas.
        subscription.convert_from_trial!(gateway: "dlocal_go")
        subscription.update!(current_period_start: period_start, current_period_end: period_end)

        period = subscription.subscription_periods.last
        period&.update!(
          amount_cents:        amount_cents,
          base_amount_cents:   subscription.base_price_cents,
          extras_amount_cents: [amount_cents - subscription.base_price_cents, 0].max
        )
      else
        subscription.update!(
          status:               "active",
          current_period_start: period_start,
          current_period_end:   period_end
        )

        if was_pending
          # Primeiro pagamento: atualiza o período criado pelo CreateService
          period = subscription.subscription_periods.last
          if period
            period.update!(
              amount_cents:        amount_cents,
              base_amount_cents:   subscription.base_price_cents,
              extras_amount_cents: [amount_cents - subscription.base_price_cents, 0].max
            )
          end
        else
          # Renovação: cria novo período apenas se não existe (idempotente)
          existing_period = subscription.subscription_periods.find_by(period_start: period_start)
          unless existing_period
            new_period = subscription.subscription_periods.create!(
              period_start:        period_start,
              period_end:          period_end,
              amount_cents:        amount_cents,
              base_amount_cents:   subscription.base_price_cents,
              extras_amount_cents: [amount_cents - subscription.base_price_cents, 0].max
            )
            replicate_period_data(subscription, new_period)
          end
        end
      end
    end

    # subscription.activated é disparado pelo callback do model (Subscription#became_active?)
    # sempre que o status muda para "active" — cobre was_pending e was_trialing sem duplicar aqui.
    return if was_pending || was_trialing

    WebhookDispatchJob.perform_later(
      customer, "payment.received",
      { amount_cents: amount_cents, gateway: "dlocal_go", charge_id: payment_id }
    )
    WebhookDispatchJob.perform_later(
      customer, "subscription.renewed",
      { period_end: period_end.iso8601 }
    )
  end

  def process_standalone_payment(payload, payment_id)
    order_id    = payload["order_id"] || payload["external_id"] || ""
    customer_id = order_id.match(/charge_(\d+)_/)[1] rescue nil
    return unless customer_id

    customer = Customer.find_by(id: customer_id)
    return unless customer

    ActsAsTenant.current_tenant = customer.account

    charge = customer.charges.find_by(gateway_charge_id: payment_id)
    charge ||= customer.charges.find_by(status: "pending", gateway: "dlocal_go")
    return unless charge

    charge.update!(status: "paid", paid_at: Time.current)

    Charges::ApplyPaidChargeService.call(charge: charge)

    WebhookDispatchJob.perform_later(
      customer, "payment.received",
      { amount_cents: charge.amount_cents, gateway: "dlocal_go", charge_id: payment_id }
    )
  end

  def process_payment_failed(subscription, payload)
    subscription.update!(status: "past_due")
    WebhookDispatchJob.perform_later(
      subscription.customer, "payment.failed",
      { gateway: "dlocal_go", status: payload["status"],
        reason: payload["status_detail"] || payload["message"] }
    )
  end

  def extract_amount(payload)
    amount = payload["amount"] || payload.dig("data", "amount") || 0
    (amount.to_f * 100).to_i
  end

  def next_period(subscription)
    case subscription.plan.billing_cycle
    when "yearly" then 1.year.from_now.beginning_of_day
    else               1.month.from_now.beginning_of_day
    end
  end

  def replicate_period_data(subscription, new_period)
    previous = subscription.subscription_periods
                           .where.not(id: new_period.id)
                           .order(created_at: :desc)
                           .first
    return unless previous

    previous.subscription_period_credits.each do |spc|
      new_period.subscription_period_credits.create!(
        credit_type: spc.credit_type, quantity: spc.quantity,
        base: spc.base, extras: spc.extras, extra_packages: spc.extra_packages
      )
      new_period.credit_snapshots.create!(
        credit_type: spc.credit_type, used: 0,
        limit: spc.quantity, synced_at: Time.current
      )
    end

    previous.subscription_period_licenses.each do |spl|
      new_period.subscription_period_licenses.create!(
        license_type: spl.license_type, quantity: spl.quantity
      )
    end
  end
end
