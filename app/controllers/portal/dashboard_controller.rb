class Portal::DashboardController < Portal::BaseController
  def show
    set_tenant!
    sub    = current_subscription
    period = sub&.current_period

    render inertia: "Portal/Dashboard", props: {
      customer:               { name: current_customer.name, email: current_customer.email },
      subscription:           sub ? serialize_subscription(sub) : nil,
      credits:                period ? serialize_credits(period) : [],
      licenses:               period ? serialize_licenses(period) : [],
      features:               sub ? serialize_features(sub) : [],
      scheduled_plan_change:  sub ? scheduled_change_info(sub) : nil,
      portal_config:          portal_config,
      branding:               branding
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

  def serialize_subscription(s)
    period = s.current_period
    {
      id:                   s.id,
      plan_name:            s.plan.name,
      plan_description:     s.plan.description,
      status:               s.status,
      managed_by:           s.managed_by,
      is_gateway_managed:   s.gateway_managed?,
      base_price_cents:     s.base_price_cents,
      period_amount_cents:  period&.amount_cents || s.base_price_cents,
      period_extras_cents:  period&.extras_amount_cents || 0,
      has_extras:           (period&.extras_amount_cents || 0) > 0,
      currency_code:        s.currency_code,
      billing_cycle:        s.plan.billing_cycle,
      current_period_end:   s.current_period_end&.strftime("%d/%m/%Y"),
      started_at:           s.started_at&.strftime("%d/%m/%Y"),
      is_trial:             s.trialing?,
      trial_ends_at:        s.trial_ends_at&.strftime("%d/%m/%Y"),
      trial_days_remaining: s.trial_days_remaining,
      trial_expired:        s.trial_expired?
    }
  end

  def serialize_credits(period)
    period.credit_snapshots.includes(:credit_type).map do |s|
      spc = period.subscription_period_credits
                  .find_by(credit_type: s.credit_type)
      {
        key:            s.credit_type.key,
        label:          s.credit_type.label,
        unit:           s.credit_type.unit,
        used:           s.used,
        limit:          s.limit,
        balance:        s.balance,
        usage_percent:  s.usage_percent,
        base:           spc&.base || s.limit,
        extras:         spc&.extras || 0,
        extra_packages: spc&.extra_packages || 0
      }
    end
  end

  def serialize_licenses(period)
    period.subscription_period_licenses
          .includes(:license_type)
          .map do |spl|
      used = current_customer.metadata
                             .dig("license_usage", spl.license_type.key).to_i
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
end
