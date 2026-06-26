class Webhooks::ProcessAsaasEventJob < ApplicationJob
  queue_as :webhooks

  def perform(event_type, payload)
    subscription = find_subscription(payload)
    return unless subscription

    ActsAsTenant.current_tenant = subscription.customer.account

    case event_type
    when "payment_received"
      process_payment_received(subscription, payload)
    when "payment_overdue"
      process_payment_overdue(subscription, payload)
    when "payment_refunded", "payment_deleted"
      process_payment_refunded(subscription, payload)
    when "subscription_cancelled"
      process_subscription_cancelled(subscription, payload)
    end
  end

  private

  def find_subscription(payload)
    ActsAsTenant.without_tenant { find_subscription_across_tenants(payload) }
  end

  def find_subscription_across_tenants(payload)
    payment      = payload["payment"] || {}
    sub_id       = payment["subscription"] || payload.dig("subscription", "id")
    external_ref = payment["externalReference"] || ""

    # 1. Tenta pelo subscription_id nativo do Asaas (gateway-managed)
    if sub_id.present?
      sub = Subscription.find_by(
        gateway:                 "asaas",
        gateway_subscription_id: sub_id
      )
      return sub if sub
    end

    # 2. Tenta pelo externalReference (billing-managed)
    # Formato: "charge_CUSTOMER_ID_TIMESTAMP" ou "plan_X_customer_Y"
    if external_ref.match?(/customer_(\d+)/)
      customer_id = external_ref.match(/customer_(\d+)/)[1]
      return find_active_asaas_sub_for(customer_id)
    end

    # 3. Tenta pelo order_id billing-managed (sub_CUSTOMERID_TIMESTAMP)
    if external_ref.match?(/\A(?:sub|renew|charge)_(\d+)_/)
      customer_id = external_ref.match(/\A(?:sub|renew|charge)_(\d+)_/)[1]
      return find_active_asaas_sub_for(customer_id)
    end

    # 4. Tenta localizar por charge existente (gateway_charge_id)
    charge_id = payment["id"]
    if charge_id.present?
      charge = Charge.find_by(gateway: "asaas", gateway_charge_id: charge_id)
      return charge.subscription if charge
    end

    nil
  end

  def find_active_asaas_sub_for(customer_id)
    customer = Customer.find_by(id: customer_id)
    return nil unless customer

    customer.subscriptions
            .where(gateway: "asaas")
            .where(status: %w[active pending past_due trialing])
            .order(created_at: :desc)
            .first
  end

  def process_payment_received(subscription, payload)
    payment      = payload["payment"] || {}
    charge_id    = payment["id"]
    amount_cents = (payment["value"].to_f * 100).to_i
    due_date     = payment["dueDate"]
    paid_at      = payment["paymentDate"] || Time.current

    # Idempotência — não processa se charge já está paid
    existing_charge = subscription.charges.find_by(gateway_charge_id: charge_id)
    return if existing_charge&.status == "paid"

    was_pending_or_trial = subscription.pending? || subscription.trialing?

    ActiveRecord::Base.transaction do
      # Atualiza charge existente ou cria nova
      if existing_charge
        existing_charge.update!(status: "paid", paid_at: Time.parse(paid_at.to_s))
      else
        charge_type = subscription.charges.where(status: "paid").exists? ? "renewal" : "new_subscription"
        subscription.charges.create!(
          customer:          subscription.customer,
          gateway:           "asaas",
          gateway_charge_id: charge_id,
          amount_cents:      amount_cents,
          status:            "paid",
          charge_type:       charge_type,
          due_date:          due_date,
          paid_at:           Time.parse(paid_at.to_s)
        )
      end

      if subscription.billing_managed? || was_pending_or_trial
        process_billing_managed_payment(subscription, amount_cents, was_pending_or_trial)
      else
        process_gateway_managed_payment(subscription, amount_cents, due_date)
      end
    end

    # Webhooks de saída
    dispatch_payment_webhooks(subscription, amount_cents, charge_id, was_pending_or_trial)
  end

  def process_billing_managed_payment(subscription, amount_cents, was_pending_or_trial)
    period_start = Time.current.beginning_of_day
    period_end   = next_period_end(subscription)

    subscription.update!(
      status:               "active",
      current_period_start: period_start,
      current_period_end:   period_end,
      converted_at:         was_pending_or_trial ? Time.current : subscription.converted_at
    )

    if was_pending_or_trial
      # Primeiro pagamento — atualiza período existente
      period = subscription.subscription_periods.order(created_at: :desc).first
      period&.update!(
        period_start:        period_start,
        period_end:          period_end,
        amount_cents:        amount_cents,
        base_amount_cents:   subscription.base_price_cents,
        extras_amount_cents: [amount_cents - subscription.base_price_cents, 0].max
      )
    else
      # Renovação — cria novo período
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

  def process_gateway_managed_payment(subscription, amount_cents, due_date)
    period_start = Time.current.beginning_of_day
    period_end   = if due_date.present?
                     Date.parse(due_date.to_s) + 1.month
                   else
                     next_period_end(subscription)
                   end

    subscription.update!(
      status:               "active",
      current_period_start: period_start,
      current_period_end:   period_end
    )

    new_period = subscription.subscription_periods.create!(
      period_start:        period_start,
      period_end:          period_end,
      amount_cents:        amount_cents,
      base_amount_cents:   subscription.base_price_cents,
      extras_amount_cents: [amount_cents - subscription.base_price_cents, 0].max
    )
    replicate_period_data(subscription, new_period)
  end

  def dispatch_payment_webhooks(subscription, amount_cents, charge_id, was_pending_or_trial)
    if was_pending_or_trial
      # O callback after_update :dispatch_activation_webhook no model já dispara
      # subscription.activated quando o status muda para "active". Não duplicar.
      nil
    else
      WebhookDispatchJob.perform_later(
        subscription.customer,
        "payment.received",
        { amount_cents: amount_cents, gateway: "asaas", charge_id: charge_id }
      )
      WebhookDispatchJob.perform_later(
        subscription.customer,
        "subscription.renewed",
        { period_end: subscription.current_period_end&.iso8601 }
      )
    end
  end

  def process_payment_overdue(subscription, _payload)
    subscription.update!(status: "past_due")

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.past_due",
      {}
    )
  end

  def process_payment_refunded(subscription, payload)
    charge_id = payload.dig("payment", "id")
    charge    = subscription.charges.find_by(gateway_charge_id: charge_id)
    charge&.update!(status: "refunded")
  end

  def process_subscription_cancelled(subscription, _payload)
    subscription.update!(status: "cancelled", cancelled_at: Time.current)

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.cancelled",
      {}
    )
  end

  def next_period_end(subscription)
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
        credit_type:   spc.credit_type,
        quantity:      spc.quantity,
        base:          spc.base,
        extras:        spc.extras,
        extra_packages: spc.extra_packages
      )
      new_period.credit_snapshots.create!(
        credit_type: spc.credit_type,
        used:        0,
        limit:       spc.quantity,
        synced_at:   Time.current
      )
    end

    previous.subscription_period_licenses.each do |spl|
      new_period.subscription_period_licenses.create!(
        license_type: spl.license_type,
        quantity:     spl.quantity
      )
    end
  end
end
