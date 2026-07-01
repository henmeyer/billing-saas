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
      started_at:         subscription.started_at&.iso8601,
      extra_packages:     subscription.metadata["extra_packages"] || {},
      available_extras:   serialize_available_extras(subscription)
    }
  end

  def update_extras
    return unless (customer = find_customer_by_external_id!(params[:external_id]))

    subscription = customer.subscriptions
                           .where(status: %w[active trialing past_due])
                           .find_by(integration: @current_integration)

    unless subscription
      render json: { error: "Sem assinatura ativa." }, status: :not_found
      return
    end

    extras_by_key  = params[:extras].to_unsafe_h.transform_keys(&:to_s).transform_values(&:to_i)
    plan_credits   = subscription.plan.plan_credits.where(allow_extras: true).includes(:credit_type)
    key_to_pc      = plan_credits.index_by { |pc| pc.credit_type.key }

    invalid_keys = extras_by_key.keys - key_to_pc.keys
    if invalid_keys.any?
      render json: { error: "Tipo(s) de crédito inválido(s): #{invalid_keys.join(', ')}" },
             status: :unprocessable_entity
      return
    end

    period = subscription.current_period
    error  = validate_extras_reduction(period, extras_by_key, key_to_pc)
    return render json: { error: error }, status: :unprocessable_entity if error

    extras_total   = 0
    packages_by_id = {}

    extras_by_key.each do |key, n|
      pc = key_to_pc[key]
      next unless pc

      extras_total += pc.extra_unit_price_cents * n
      packages_by_id[pc.credit_type_id.to_s] = n
    end

    new_amount = subscription.base_price_cents + extras_total

    if subscription.gateway_managed?
      adapter = Gateways::Base.for(subscription.gateway)
      adapter.update_subscription(subscription.gateway_subscription_id, subscription.plan,
                                  amount_cents: new_amount)
    end

    period&.update!(amount_cents: new_amount, extras_amount_cents: extras_total)
    update_period_credits(period, plan_credits, packages_by_id)

    subscription.update!(metadata: subscription.metadata.merge("extra_packages" => packages_by_id))

    WebhookDispatchJob.perform_later(customer, "subscription.updated", {})

    render json: {
      external_id:        params[:external_id],
      extras_total_cents: extras_total,
      new_amount_cents:   new_amount,
      extra_packages:     packages_by_id
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

  def validate_extras_reduction(period, extras_by_key, key_to_pc)
    return unless period

    extras_by_key.each do |key, n|
      pc = key_to_pc[key]
      next unless pc

      new_total = pc.quantity + (pc.extra_unit_size * n)
      snapshot  = period.credit_snapshots.find_by(credit_type: pc.credit_type)
      next unless snapshot && snapshot.used > new_total

      return "Não é possível reduzir #{pc.credit_type.label}: " \
             "utilizado #{snapshot.used} #{pc.credit_type.unit}s, " \
             "mínimo permitido seria #{snapshot.used}"
    end

    nil
  end

  def update_period_credits(period, plan_credits, packages_by_id)
    return unless period

    plan_credits.each do |pc|
      n   = packages_by_id[pc.credit_type_id.to_s] || 0
      spc = period.subscription_period_credits.find_by(credit_type: pc.credit_type)
      next unless spc

      new_extras = pc.extra_unit_size * n
      new_total  = pc.quantity + new_extras
      spc.update!(quantity: new_total, extras: new_extras, extra_packages: n)
      period.credit_snapshots.find_by(credit_type: pc.credit_type)&.update!(limit: new_total)
    end
  end

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

  def serialize_available_extras(sub)
    current = sub.metadata["extra_packages"] || {}
    sub.plan.plan_credits.where(allow_extras: true).includes(:credit_type).map do |pc|
      {
        credit_type_key:  pc.credit_type.key,
        label:            pc.credit_type.label,
        unit:             pc.credit_type.unit,
        extra_unit_size:  pc.extra_unit_size,
        price_cents:      pc.extra_unit_price_cents,
        current_packages: (current[pc.credit_type_id.to_s] || 0).to_i
      }
    end
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
