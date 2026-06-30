class Webhooks::ProcessStripeEventJob < ApplicationJob
  queue_as :webhooks

  def perform(event_type, payload)
    subscription = find_subscription(payload)
    return unless subscription

    ActsAsTenant.current_tenant = subscription.customer.account

    case event_type
    when "payment_received"
      process_payment_received(subscription, payload)
    when "payment_failed"
      process_payment_failed(subscription, payload)
    when "subscription_cancelled"
      process_subscription_cancelled(subscription, payload)
    when "subscription_updated"
      process_subscription_updated(subscription, payload)
    end
  end

  private

  def find_subscription(payload)
    sub_id = payload["subscription"] || payload["id"]
    return unless sub_id

    Subscription.find_by(
      gateway:                 "stripe",
      gateway_subscription_id: sub_id
    )
  end

  def process_payment_received(subscription, payload)
    charge_id    = payload["charge"] || payload["id"]
    amount       = payload["amount_paid"].to_i
    period_start = Time.at(payload["period_start"].to_i)
    period_end   = Time.at(payload["period_end"].to_i)

    # Charges avulsas (produto/troca de plano) aplicam efeitos sem renovar.
    existing = subscription.charges.find_by(gateway_charge_id: charge_id)
    if existing && (existing.charge_type_product? || existing.charge_type_plan_change?)
      apply_standalone_charge(existing)
      return
    end

    return if subscription.charges.exists?(gateway_charge_id: charge_id)

    charge_type = subscription.charges.exists? ? "renewal" : "new_subscription"

    ActiveRecord::Base.transaction do
      subscription.charges.create!(
        customer:          subscription.customer,
        gateway:           "stripe",
        gateway_charge_id: charge_id,
        amount_cents:      amount,
        status:            "paid",
        charge_type:       charge_type,
        paid_at:           Time.current
      )

      subscription.update!(
        status:               "active",
        current_period_start: period_start,
        current_period_end:   period_end
      )

      subscription.subscription_periods.create!(
        period_start: period_start,
        period_end:   period_end
      )
    end

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "payment.received",
      { amount_cents: amount, gateway: "stripe", charge_id: charge_id }
    )

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.renewed",
      { period_end: period_end }
    )
  end

  def process_payment_failed(subscription, payload)
    subscription.update!(status: "past_due")

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "payment.failed",
      {
        amount_cents: payload["amount_due"].to_i,
        gateway:      "stripe",
        attempt:      payload["attempt_count"].to_i
      }
    )
  end

  # Marca a charge avulsa como paga e aplica seus efeitos sem renovar.
  def apply_standalone_charge(charge)
    charge.update!(status: "paid", paid_at: Time.current) unless charge.paid?
    Charges::ApplyPaidChargeService.call(charge: charge)

    WebhookDispatchJob.perform_later(
      charge.customer,
      "payment.received",
      { amount_cents: charge.amount_cents, gateway: "stripe", charge_id: charge.gateway_charge_id }
    )
  end

  def process_subscription_cancelled(subscription, _payload)
    subscription.update!(status: "cancelled", cancelled_at: Time.current)

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.cancelled",
      {}
    )
  end

  def process_subscription_updated(subscription, payload)
    new_price_id = payload.dig("items", "data", 0, "price", "id")
    return unless new_price_id

    new_plan = ActsAsTenant.current_tenant
                           .plans
                           .find_by("gateway_data -> 'stripe' ->> 'price_id' = ?", new_price_id)
    return unless new_plan
    return if subscription.plan_id == new_plan.id

    old_plan = subscription.plan
    subscription.subscription_plan_changes.create!(
      from_plan: old_plan,
      to_plan:   new_plan,
      reason:    "gateway_sync"
    )
    subscription.update!(plan: new_plan)

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "plan.changed",
      {
        previous_plan: { id: old_plan.id, name: old_plan.name },
        new_plan:      { id: new_plan.id, name: new_plan.name }
      }
    )
  end
end
