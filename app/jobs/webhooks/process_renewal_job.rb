class Webhooks::ProcessRenewalJob < ApplicationJob
  queue_as :webhooks

  def perform(gateway, payload)
    subscription = find_subscription(gateway, payload)
    return unless subscription

    ActsAsTenant.current_tenant = subscription.customer.account

    period_start = extract_period_start(payload)
    period_end   = extract_period_end(payload, subscription)

    ActiveRecord::Base.transaction do
      subscription.charges.create!(
        customer:          subscription.customer,
        gateway:           gateway,
        gateway_charge_id: extract_charge_id(payload),
        amount_cents:      extract_amount(payload),
        status:            "paid",
        paid_at:           Time.current
      )

      subscription.update!(
        status:               "active",
        current_period_start: period_start,
        current_period_end:   period_end
      )

      new_period = subscription.subscription_periods.create!(
        period_start: period_start,
        period_end:   period_end
      )

      replicate_quantities(subscription, new_period)
    end

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.renewed",
      { period_end: period_end }
    )
  end

  private

  def find_subscription(gateway, payload)
    gateway_sub_id = payload.dig("subscription", "id") || payload["subscriptionId"]
    Subscription.find_by(gateway: gateway, gateway_subscription_id: gateway_sub_id)
  end

  def extract_period_start(payload)
    raw = payload["dateCreated"] || payload.dig("current_period_start")
    raw ? Time.parse(raw.to_s) : Time.current
  end

  def extract_period_end(payload, subscription)
    raw = payload["nextDueDate"] || payload.dig("current_period_end")
    raw ? Time.parse(raw.to_s) : (Time.current + 1.month)
  end

  def extract_charge_id(payload)
    payload["id"] || payload["chargeId"] || "renewal_#{SecureRandom.hex(8)}"
  end

  def extract_amount(payload)
    cents = payload["value"] || payload["amount"]
    return 0 unless cents
    (cents.to_f * 100).to_i
  end

  def replicate_quantities(subscription, new_period)
    previous_period = subscription.subscription_periods
                                  .order(created_at: :desc)
                                  .offset(1)
                                  .first

    if previous_period
      new_period.update!(
        amount_cents:        previous_period.amount_cents,
        base_amount_cents:   previous_period.base_amount_cents,
        extras_amount_cents: previous_period.extras_amount_cents
      )

      previous_period.subscription_period_credits.each do |spc|
        new_period.subscription_period_credits.create!(
          credit_type:    spc.credit_type,
          quantity:       spc.quantity,
          base:           spc.base,
          extras:         spc.extras,
          extra_packages: spc.extra_packages
        )

        new_period.credit_snapshots.create!(
          credit_type: spc.credit_type,
          used:        0,
          limit:       spc.quantity,
          synced_at:   Time.current
        )
      end

      previous_period.subscription_period_licenses.each do |spl|
        new_period.subscription_period_licenses.create!(
          license_type: spl.license_type,
          quantity:     spl.quantity
        )
      end
    else
      create_period_from_plan(new_period, subscription)
    end
  end

  def create_period_from_plan(period, subscription)
    pricing = Pricing::CalculateService.call(
      plan:           subscription.plan,
      customer:       subscription.customer,
      currency:       subscription.effective_currency,
      extra_packages: subscription.metadata["extra_packages"] || {}
    )

    base_price   = subscription.base_price_cents
    extras_total = [pricing.amount_cents - base_price, 0].max

    period.update!(
      amount_cents:        pricing.amount_cents,
      base_amount_cents:   base_price,
      extras_amount_cents: extras_total
    )

    subscription.plan.plan_credits.includes(:credit_type).each do |pc|
      extra_item = pricing.extras_breakdown&.find { |e| e[:credit_type_id] == pc.credit_type_id }
      base_qty   = pc.quantity
      extra_qty  = extra_item&.dig(:extra_quantity) || 0
      total_qty  = base_qty + extra_qty

      period.subscription_period_credits.create!(
        credit_type:    pc.credit_type,
        quantity:       total_qty,
        base:           base_qty,
        extras:         extra_qty,
        extra_packages: extra_item&.dig(:extra_packages) || 0
      )

      period.credit_snapshots.create!(
        credit_type: pc.credit_type,
        used:        0,
        limit:       total_qty,
        synced_at:   Time.current
      )
    end

    subscription.plan.plan_licenses.includes(:license_type).each do |pl|
      period.subscription_period_licenses.create!(
        license_type: pl.license_type,
        quantity:     pl.quantity
      )
    end
  end
end
