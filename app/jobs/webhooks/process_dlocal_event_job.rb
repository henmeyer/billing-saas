class Webhooks::ProcessDlocalEventJob < ApplicationJob
  queue_as :webhooks

  def perform(event_type, payload)
    order_id  = payload["order_id"].to_s
    charge_id = payload["id"]

    subscription = find_subscription(order_id, payload)
    return unless subscription

    ActsAsTenant.current_tenant = subscription.customer.account

    case event_type
    when "payment_received" then process_payment_received(subscription, payload, charge_id)
    when "payment_failed"   then process_payment_failed(subscription, payload)
    end
  end

  private

  def find_subscription(order_id, payload)
    external_ref = payload["external_reference"].to_s

    if (match = external_ref.match(/customer_(\d+)/))
      customer = Customer.find_by(id: match[1])
      return customer&.active_subscription
    end

    if (match = order_id.match(/sub_(\d+)_/))
      customer = Customer.find_by(id: match[1])
      return customer&.active_subscription
    end

    nil
  end

  def process_payment_received(subscription, payload, charge_id)
    amount_cents = (payload["amount"].to_f * 100).to_i

    return if subscription.charges.exists?(gateway_charge_id: charge_id)

    period_start = Time.current.beginning_of_day
    period_end   = 1.month.from_now.beginning_of_day

    ActiveRecord::Base.transaction do
      subscription.charges.create!(
        customer:          subscription.customer,
        gateway:           "dlocal",
        gateway_charge_id: charge_id,
        amount_cents:      amount_cents,
        status:            "paid",
        paid_at:           Time.current,
        redirect_url:      payload["redirect_url"] || payload["ticket_url"],
        charge_data:       payload.slice("status", "status_detail", "payment_method_id")
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
      { amount_cents:, gateway: "dlocal", charge_id: }
    )

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.renewed",
      { period_end: }
    )
  end

  def process_payment_failed(subscription, payload)
    subscription.update!(status: "past_due")

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "payment.failed",
      { gateway: "dlocal", status: payload["status"], reason: payload["status_detail"] }
    )
  end
end
