class Portal::DashboardController < Portal::BaseController
  def show
    set_tenant!
    sub    = current_subscription
    period = sub&.current_period

    render inertia: "Portal/Dashboard", props: {
      customer:              { name: current_customer.name, email: current_customer.email },
      subscription:          sub ? serialize_subscription(sub) : nil,
      credits:               period ? serialize_credits(period) : [],
      licenses:              period ? serialize_licenses(period) : [],
      features:              sub ? serialize_features(sub) : [],
      extras_options:        sub ? serialize_extras_options(sub) : [],
      scheduled_plan_change: sub ? scheduled_change_info(sub) : nil,
      portal_config:         portal_config,
      branding:              branding
    }
  end

  private

  def scheduled_change_info(sub)
    scheduled = sub.metadata&.dig("scheduled_plan_change")
    return nil if scheduled.blank?

    plan = Plan.find_by(id: scheduled["plan_id"])
    {
      plan_name:    plan&.name,
      effective_at: scheduled["effective_at"]
    }
  end

  def serialize_subscription(sub)
    period = sub.current_period
    {
      id:                   sub.id,
      plan_name:            sub.plan.name,
      plan_description:     sub.plan.description,
      status:               sub.status,
      managed_by:           sub.managed_by,
      is_gateway_managed:   sub.gateway_managed?,
      base_price_cents:     sub.base_price_cents,
      period_amount_cents:  period&.amount_cents || sub.base_price_cents,
      period_extras_cents:  period&.extras_amount_cents || 0,
      has_extras:           (period&.extras_amount_cents || 0).positive?,
      currency_code:        sub.currency_code,
      billing_cycle:        sub.plan.billing_cycle,
      current_period_end:   sub.current_period_end&.strftime("%d/%m/%Y"),
      started_at:           sub.started_at&.strftime("%d/%m/%Y"),
      is_trial:             sub.trialing?,
      trial_ends_at:        sub.trial_ends_at&.strftime("%d/%m/%Y"),
      trial_days_remaining: sub.trial_days_remaining,
      trial_expired:        sub.trial_expired?
    }
  end

  def serialize_credits(period)
    period.credit_snapshots.includes(:credit_type).map do |snap|
      spc = period.subscription_period_credits.find_by(credit_type: snap.credit_type)
      {
        key:            snap.credit_type.key,
        label:          snap.credit_type.label,
        unit:           snap.credit_type.unit,
        used:           snap.used,
        limit:          snap.limit,
        balance:        snap.balance,
        usage_percent:  snap.usage_percent,
        base:           spc&.base || snap.limit,
        extras:         spc&.extras || 0,
        extra_packages: spc&.extra_packages || 0
      }
    end
  end

  def serialize_licenses(period)
    period.subscription_period_licenses.includes(:license_type).map do |spl|
      used = current_customer.metadata.dig("license_usage", spl.license_type.key).to_i
      {
        key:       spl.license_type.key,
        label:     spl.license_type.label,
        unit:      spl.license_type.unit,
        quantity:  spl.quantity,
        unlimited: spl.unlimited?,
        used:      used
      }
    end
  end

  def serialize_features(sub)
    sub.plan.plan_features.includes(:feature_type).map do |pf|
      {
        key:     pf.feature_type.key,
        label:   pf.feature_type.label,
        enabled: pf.enabled
      }
    end
  end

  def serialize_extras_options(sub)
    current_packages = sub.metadata["extra_packages"] || {}

    sub.plan.plan_credits.where(allow_extras: true).includes(:credit_type).map do |pc|
      {
        credit_type_id:   pc.credit_type_id,
        credit_type_key:  pc.credit_type.key,
        label:            pc.credit_type.label,
        unit:             pc.credit_type.unit,
        extra_unit_size:  pc.extra_unit_size,
        price_cents:      pc.extra_unit_price_cents,
        current_packages: (current_packages[pc.credit_type_id.to_s] || 0).to_i
      }
    end
  end
end
