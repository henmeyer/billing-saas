class Webhooks::ProcessDlocalGoEventJob < ApplicationJob
  queue_as :webhooks

  def perform(event_type, payload)
    data = payload["data"] || payload

    subscription = find_subscription(event_type, data)
    return unless subscription

    ActsAsTenant.current_tenant = subscription.customer.account

    case event_type
    when "subscription_activated" then process_subscription_activated(subscription, data)
    when "payment_received"       then process_payment_received(subscription, data)
    when "payment_failed"         then process_payment_failed(subscription, data)
    when "subscription_cancelled" then process_subscription_cancelled(subscription)
    end
  end

  private

  # Subscription activation: match by customer email (data.client_email)
  # Payment events: match by gateway_subscription_id "plan_id|subscription_id"
  def find_subscription(event_type, data)
    if %w[subscription_activated subscription_cancelled].include?(event_type)
      find_by_email(data["client_email"])
    else
      dlocalgo_sub_id = data["subscription_id"] || data["id"]
      find_by_dlocalgo_id(dlocalgo_sub_id)
    end
  end

  def find_by_email(email)
    return unless email.present?

    customer = Customer.find_by(email: email)
    customer&.subscriptions&.where(gateway: "dlocal_go")&.active&.last
  end

  def find_by_dlocalgo_id(dlocalgo_sub_id)
    return unless dlocalgo_sub_id.present?

    Subscription.where("gateway_subscription_id LIKE ?", "%|#{dlocalgo_sub_id}").first
  end

  def process_subscription_activated(subscription, data)
    plan_id         = data.dig("plan", "id").to_s
    subscription_id = data["id"].to_s

    subscription.update!(
      status:                 "active",
      gateway_subscription_id: "#{plan_id}|#{subscription_id}"
    )

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.activated",
      { plan: { id: subscription.plan.id, name: subscription.plan.name } }
    )
  end

  def process_payment_received(subscription, data)
    charge_id    = data["id"].to_s
    amount_cents = (data["amount"].to_f * 100).to_i

    return if subscription.charges.exists?(gateway_charge_id: charge_id)

    period_start = Time.current.beginning_of_day
    period_end   = 1.month.from_now.beginning_of_day

    ActiveRecord::Base.transaction do
      subscription.charges.create!(
        customer:          subscription.customer,
        gateway:           "dlocal_go",
        gateway_charge_id: charge_id,
        amount_cents:      amount_cents,
        status:            "paid",
        paid_at:           Time.current,
        charge_data:       data.slice("status", "currency", "payment_method_id")
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
      { amount_cents:, gateway: "dlocal_go", charge_id: }
    )

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.renewed",
      { period_end: }
    )
  end

  def process_payment_failed(subscription, data)
    subscription.update!(status: "past_due")

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "payment.failed",
      { gateway: "dlocal_go", status: data["status"], reason: data["status_detail"] }
    )
  end

  def process_subscription_cancelled(subscription)
    subscription.update!(status: "cancelled", cancelled_at: Time.current)
    WebhookDispatchJob.perform_later(subscription.customer, "subscription.cancelled", {})
  end
end
