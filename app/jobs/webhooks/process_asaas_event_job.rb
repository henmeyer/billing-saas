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
    when "payment_refunded"
      process_payment_refunded(subscription, payload)
    when "subscription_cancelled"
      process_subscription_cancelled(subscription, payload)
    end
  end

  private

  def find_subscription(payload)
    sub_id = payload.dig("payment", "subscription") ||
             payload.dig("subscription", "id")
    return unless sub_id

    Subscription.find_by(
      gateway:                 "asaas",
      gateway_subscription_id: sub_id
    )
  end

  def process_payment_received(subscription, payload)
    charge_id = payload.dig("payment", "id")
    amount    = (payload.dig("payment", "value").to_f * 100).to_i
    due_date  = payload.dig("payment", "dueDate")
    paid_at   = payload.dig("payment", "paymentDate") || Time.current

    return if subscription.charges.exists?(gateway_charge_id: charge_id)

    ActiveRecord::Base.transaction do
      subscription.charges.create!(
        customer:          subscription.customer,
        gateway:           "asaas",
        gateway_charge_id: charge_id,
        amount_cents:      amount,
        status:            "paid",
        due_date:          due_date,
        paid_at:           Time.parse(paid_at.to_s)
      )

      period_start = Time.current.beginning_of_day
      period_end   = 1.month.from_now.beginning_of_day

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
      { amount_cents: amount, gateway: "asaas", charge_id: charge_id }
    )

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.renewed",
      { period_end: subscription.current_period_end }
    )
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
end
