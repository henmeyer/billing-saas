class Portal::PlansController < Portal::BaseController
  before_action :require_plan_change!

  def index
    set_tenant!
    available_plans = Plan.active
                          .joins(:plan_integrations)
                          .where(plan_integrations: {
                                   integration_id: current_integration.id
                                 })
                          .includes(:plan_prices, :plan_credits,
                                    :plan_licenses, :plan_features)

    render inertia: "Portal/Plans/Index", props: {
      current_plan_id: current_subscription&.plan_id,
      plans:           available_plans.map { |p| serialize_plan(p) },
      currency_code:   current_subscription&.currency_code || "BRL",
      prorate_info:    prorate_info,
      scheduled:       scheduled_change_info,
      portal_config:   portal_config,
      branding:        branding
    }
  end

  def update
    set_tenant!
    new_plan = Plan.find(params[:id])

    result = Subscriptions::PlanChangeService.call(
      subscription: current_subscription,
      new_plan:     new_plan,
      changed_by:   current_customer
    )

    case result.type
    when :upgrade, :upgrade_scheduled
      handle_upgrade(result, new_plan)
    else # :downgrade
      render json: { notice: "Downgrade para #{new_plan.name} agendado para o fim do período atual." }
    end
  rescue StandardError => e
    render json: { error: "Erro ao trocar de plano: #{e.message}" }, status: :unprocessable_entity
  end

  private

  # Dados para o portal estimar a diferença pró-rata de um upgrade.
  def prorate_info
    sub = current_subscription
    return { days_remaining: 0, days_total: 0, current_base_cents: 0 } unless sub

    period_start = sub.current_period_start&.to_date
    period_end   = sub.current_period_end&.to_date
    total        = (period_start && period_end) ? (period_end - period_start).to_i : 0
    remaining    = period_end ? (period_end - Date.current).to_i.clamp(0, [total, 0].max) : 0

    {
      days_remaining:     remaining,
      days_total:         total,
      current_base_cents: sub.base_price_cents.to_i
    }
  end

  def scheduled_change_info
    scheduled = current_subscription&.metadata&.dig("scheduled_plan_change")
    return nil if scheduled.blank?

    plan = Plan.find_by(id: scheduled["plan_id"])
    {
      plan_id:      scheduled["plan_id"],
      plan_name:    plan&.name,
      effective_at: scheduled["effective_at"]
    }
  end

  def handle_upgrade(result, new_plan)
    if result.charge.nil?
      render json: { notice: "Upgrade para #{new_plan.name} agendado para o próximo ciclo." }
    elsif result.charge.redirect_url.present?
      render json: { payment_url: result.charge.redirect_url }
    else
      render json: { payment_url: portal_checkout_url(token: portal_token, charge_id: result.charge.id) }
    end
  end

  def require_plan_change!
    return if portal_config["allow_plan_change"]

    redirect_to portal_dashboard_path(token: portal_token),
                alert: "Troca de plano não disponível."
  end

  def serialize_plan(plan)
    currency = Currency.find_by(code: current_subscription&.currency_code || "BRL")
    {
      id:            plan.id,
      name:          plan.name,
      description:   plan.description,
      price_cents:   plan.price_for(currency),
      billing_cycle: plan.billing_cycle,
      is_current:    plan.id == current_subscription&.plan_id,
      credits:       plan.plan_credits.includes(:credit_type).map do |pc|
        { label: pc.credit_type.label, quantity: pc.quantity,
          unit: pc.credit_type.unit }
      end,
      licenses:      plan.plan_licenses.includes(:license_type).map do |pl|
        { label: pl.license_type.label, quantity: pl.quantity,
          unit: pl.license_type.unit }
      end,
      features:      plan.plan_features.includes(:feature_type)
                         .where(enabled: true)
                         .map { |pf| { label: pf.feature_type.label } }
    }
  end
end
