class Api::V1::SubscriptionsController < Api::V1::BaseController
  def show
    return unless (customer = find_customer_by_external_id!(params[:external_id]))

    integration = resolve_integration
    return unless integration

    subscription = customer.subscriptions
                           .where(status: %w[active trialing past_due])
                           .find_by(integration: integration)

    unless subscription
      render json: {
        error: "Sem assinatura ativa para a integração '#{integration.name}'"
      }, status: :not_found
      return
    end

    render json: {
      customer_id:        params[:external_id],
      integration_id:     subscription.integration_id,
      integration_name:   subscription.integration.name,
      plan:               {
        id:            subscription.plan.id,
        name:          subscription.plan.name,
        billing_cycle: subscription.plan.billing_cycle,
        price_cents:   subscription.price_in_currency,
        currency:      subscription.effective_currency&.code
      },
      status:             subscription.status,
      gateway:            subscription.gateway,
      managed_by:         subscription.managed_by,
      is_gateway_managed: subscription.gateway_managed?,
      current_period_end: subscription.current_period_end&.iso8601,
      started_at:         subscription.started_at&.iso8601
    }
  end

  def create
    return unless (customer = find_customer_by_external_id!(params[:external_id]))

    plan = ActsAsTenant.with_tenant(@current_account) do
      Plan.active.find_by(id: params.require(:plan_id))
    end

    unless plan
      render json: { error: "Plano não encontrado" }, status: :not_found
      return
    end

    trial_ends_at = params[:trial_ends_at].present? ? Time.zone.parse(params[:trial_ends_at]) : nil
    status        = trial_ends_at ? "trialing" : "active"
    now           = Time.current
    period_end    = plan.billing_cycle == "yearly" ? now + 1.year : now + 1.month
    currency      = customer.effective_currency

    subscription = customer.subscriptions.new(
      plan:                 plan,
      integration:          @current_integration,
      status:               status,
      managed_by:           "billing",
      gateway:              nil,
      started_at:           now,
      trial_ends_at:        trial_ends_at,
      current_period_start: now,
      current_period_end:   period_end,
      base_price_cents:     plan.price_for(currency),
      currency:             currency
    )

    unless subscription.save
      render json: { errors: subscription.errors.as_json }, status: :unprocessable_entity
      return
    end

    subscription.subscription_periods.create!(
      period_start: now,
      period_end:   period_end,
      amount_cents: subscription.base_price_cents
    )

    render json: serialize_subscription(subscription, params[:external_id]), status: :created
  end

  private

  def serialize_subscription(sub, external_id)
    {
      external_id:        external_id,
      integration_id:     sub.integration_id,
      plan:               {
        id:            sub.plan.id,
        name:          sub.plan.name,
        billing_cycle: sub.plan.billing_cycle,
        price_cents:   sub.base_price_cents,
        currency:      sub.effective_currency&.code
      },
      status:             sub.status,
      managed_by:         sub.managed_by,
      trial_ends_at:      sub.trial_ends_at&.iso8601,
      current_period_end: sub.current_period_end&.iso8601,
      started_at:         sub.started_at&.iso8601
    }
  end

  def resolve_integration
    if params[:integration_id].present?
      integration = Integration.find_by(id: params[:integration_id])
      unless integration
        render json: { error: "Integração não encontrada" }, status: :not_found
        return nil
      end
      integration
    else
      @current_integration
    end
  end
end
