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
      portal_config:   portal_config,
      branding:        branding
    }
  end

  def update
    set_tenant!
    new_plan = Plan.find(params[:id])

    begin
      current_subscription.change_plan!(
        new_plan,
        changed_by: current_customer
      )
      redirect_to portal_dashboard_path(token: portal_token),
                  notice: "Plano alterado para #{new_plan.name}."
    rescue => e
      redirect_to portal_plans_path(token: portal_token),
                  alert: "Erro ao trocar de plano: #{e.message}"
    end
  end

  private

  def require_plan_change!
    unless portal_config["allow_plan_change"]
      redirect_to portal_dashboard_path(token: portal_token),
                  alert: "Troca de plano não disponível."
    end
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
      credits: plan.plan_credits.includes(:credit_type).map { |pc|
        { label: pc.credit_type.label, quantity: pc.quantity,
          unit: pc.credit_type.unit }
      },
      licenses: plan.plan_licenses.includes(:license_type).map { |pl|
        { label: pl.license_type.label, quantity: pl.quantity,
          unit: pl.license_type.unit }
      },
      features: plan.plan_features.includes(:feature_type)
                    .where(enabled: true)
                    .map { |pf| { label: pf.feature_type.label } }
    }
  end
end
