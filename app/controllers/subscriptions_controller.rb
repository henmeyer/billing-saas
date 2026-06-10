class SubscriptionsController < ApplicationController
  before_action :set_customer, except: [:index]
  before_action :set_subscription, only: [:edit, :update, :destroy]
  before_action :require_admin!

  def index
    subscriptions = Subscription
                    .includes(:customer, :plan, :integration, :currency, plan: :plan_prices)
                    .order(created_at: :desc)

    render inertia: "Subscriptions/Index", props: {
      subscriptions: subscriptions.map { |sub| serialize_subscription_row(sub) },
      customers:     Customer.order(:name).map { |c| { id: c.id, name: c.name } }
    }
  end

  def new
    render inertia: "Subscriptions/Form", props: {
      customer:               serialize_customer(@customer),
      subscription:           {},
      plans:                  serialize_plans,
      gateways:               serialize_gateways,
      currencies:             serialize_currencies,
      default_currency_id:    @customer.effective_currency&.id,
      available_integrations: serialize_available_integrations,
      selected_integration_id: params[:integration_id]&.to_i,
      errors:                 {}
    }
  end

  def create
    result = Subscriptions::CreateService.call(
      customer:                @customer,
      plan_id:                 params[:plan_id],
      gateway:                 params[:gateway],
      integration_id:          params[:integration_id],
      currency_id:             params[:currency_id],
      started_at:              params[:started_at] || Time.current,
      gateway_subscription_id: params[:gateway_subscription_id],
      extra_packages:          params[:extra_packages]&.to_unsafe_h || {},
      initial_quantity:        params[:initial_quantity]&.to_i
    )

    if result.success?
      redirect_to customer_path(@customer), notice: "Assinatura criada com sucesso."
    else
      render inertia: "Subscriptions/Form", props: {
        customer:               serialize_customer(@customer),
        subscription:           params.permit(:plan_id, :gateway, :currency_id, :integration_id),
        plans:                  serialize_plans,
        gateways:               serialize_gateways,
        currencies:             serialize_currencies,
        default_currency_id:    @customer.effective_currency&.id,
        available_integrations: serialize_available_integrations,
        errors:                 result.errors
      }
    end
  end

  def edit
    render inertia: "Subscriptions/Form", props: {
      customer:               serialize_customer(@customer),
      subscription:           serialize_subscription(@subscription),
      plans:                  serialize_plans,
      gateways:               serialize_gateways,
      currencies:             serialize_currencies,
      default_currency_id:    @customer.effective_currency&.id,
      available_integrations: serialize_available_integrations,
      linked_integration:     serialize_linked_integration(@subscription.integration),
      errors:                 {}
    }
  end

  def update
    if params[:plan_id].present? && params[:plan_id].to_i != @subscription.plan_id
      new_plan = Plan.find(params[:plan_id])
      @subscription.change_plan!(new_plan, changed_by: current_user)
    end

    extra_packages   = params[:extra_packages]&.to_unsafe_h || {}
    initial_quantity = params[:initial_quantity]&.to_i

    @subscription.update!(
      status:   params[:status] || @subscription.status,
      metadata: @subscription.metadata.merge("extra_packages" => extra_packages)
    )

    update_period_records(extra_packages, initial_quantity:)

    redirect_to customer_path(@customer), notice: "Assinatura atualizada."
  rescue StandardError => e
    redirect_to customer_path(@customer), alert: e.message
  end

  def destroy
    @subscription.cancel!
    redirect_to customer_path(@customer), notice: "Assinatura cancelada."
  rescue StandardError => e
    redirect_to customer_path(@customer), alert: e.message
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_subscription
    @subscription = @customer.subscriptions.find(params[:id])
  end

  def serialize_customer(customer)
    { id: customer.id, name: customer.name, email: customer.email }
  end

  def serialize_subscription(sub)
    period = sub.current_period
    {
      id:                      sub.id,
      plan_id:                 sub.plan_id,
      integration_id:          sub.integration_id,
      integration_name:        sub.integration&.name,
      gateway:                 sub.gateway,
      gateway_subscription_id: sub.gateway_subscription_id,
      status:                  sub.status,
      currency_id:             sub.currency_id,
      currency_code:           sub.currency&.code,
      base_price_cents:        sub.base_price_cents,
      period_amount_cents:     period&.amount_cents || sub.base_price_cents,
      period_base_cents:       period&.base_amount_cents || sub.base_price_cents,
      period_extras_cents:     period&.extras_amount_cents || 0,
      current_quantity:        current_quantity_for(sub),
      started_at:              sub.started_at&.strftime("%Y-%m-%d"),
      current_period_end:      sub.current_period_end&.strftime("%Y-%m-%d"),
      current_extra_packages:  period ? extract_extra_packages(period) : {}
    }
  end

  def current_quantity_for(sub)
    plan = sub.plan
    case plan.pricing_model
    when "flat"     then 1
    when "per_unit"
      unit_price = plan.unit_price_for(sub.effective_currency)
      unit_price.zero? ? 1 : (sub.base_price_cents.to_f / unit_price).round
    when "volume"
      plan.current_quantity_for(sub.customer)
    else
      1
    end
  end

  def serialize_subscription_row(sub)
    {
      id:                 sub.id,
      status:             sub.status,
      gateway:            sub.gateway,
      plan_name:          sub.plan&.name,
      integration_id:     sub.integration_id,
      integration_name:   sub.integration&.name,
      base_price_cents:   sub.base_price_cents,
      billing_cycle:      sub.plan&.billing_cycle,
      currency_code:      sub.currency_code,
      current_period_end: sub.current_period_end&.strftime("%d/%m/%Y"),
      started_at:         sub.started_at&.strftime("%d/%m/%Y"),
      customer:           { id: sub.customer.id, name: sub.customer.name }
    }
  end

  def serialize_plans
    Plan.active
        .includes(:plan_pricing_tiers, :plan_credits, :plan_licenses, :plan_integrations,
                  plan_prices:   :currency,
                  plan_credits:  :credit_type,
                  plan_licenses: :license_type)
        .map do |plan|
      {
        id:                   plan.id,
        name:                 plan.name,
        billing_cycle:        plan.billing_cycle,
        pricing_model:        plan.pricing_model,
        pricing_metric_label: plan.pricing_metric_label,
        integration_ids:      plan.plan_integrations.map(&:integration_id),
        prices:               plan.plan_prices.map do |pp|
          {
            currency_id:     pp.currency_id,
            currency_code:   pp.currency.code,
            currency_symbol: pp.currency.symbol,
            amount_cents:    pp.amount_cents
          }
        end,
        pricing_tiers:        plan.plan_pricing_tiers.ordered.map do |t|
          {
            currency_id:       t.currency_id,
            from_unit:         t.from_unit,
            to_unit:           t.to_unit,
            unit_amount_cents: t.unit_amount_cents,
            label:             t.label
          }
        end,
        credits:              plan.plan_credits.map do |pc|
          {
            credit_type_id:         pc.credit_type_id,
            credit_type_key:        pc.credit_type&.key,
            credit_type_label:      pc.credit_type&.label,
            credit_type_unit:       pc.credit_type&.unit,
            quantity:               pc.quantity,
            allow_extras:           pc.allow_extras,
            extra_unit_size:        pc.extra_unit_size,
            extra_unit_price_cents: pc.extra_unit_price_cents
          }
        end,
        licenses:             plan.plan_licenses.map do |pl|
          {
            license_type_id:    pl.license_type_id,
            license_type_label: pl.license_type&.label,
            license_type_unit:  pl.license_type&.unit,
            quantity:           pl.quantity
          }
        end
      }
    end
  end

  def update_period_records(extra_packages, initial_quantity: nil)
    period = @subscription.current_period
    return unless period

    plan = @subscription.plan
    pricing = Pricing::CalculateService.call(
      plan:             plan,
      customer:         @subscription.customer,
      currency:         @subscription.effective_currency,
      extra_packages:   extra_packages,
      initial_quantity: initial_quantity
    )

    base_price   = plan.calculate_price(pricing.quantity, @subscription.effective_currency)
    extras_total = [pricing.amount_cents - base_price, 0].max

    period.update!(
      amount_cents:        pricing.amount_cents,
      base_amount_cents:   base_price,
      extras_amount_cents: extras_total
    )

    @subscription.update_column(:base_price_cents, base_price)

    @subscription.plan.plan_credits.each do |pc|
      n_packages = extra_packages[pc.credit_type_id.to_s].to_i
      extra_qty  = n_packages * pc.extra_unit_size
      total_qty  = pc.quantity + extra_qty

      period.subscription_period_credits
            .find_by(credit_type_id: pc.credit_type_id)
            &.update!(quantity: total_qty, extras: extra_qty, extra_packages: n_packages)

      snapshot = period.credit_snapshots.find_by(credit_type_id: pc.credit_type_id)
      snapshot&.update!(
        limit:   total_qty,
        balance: [total_qty - snapshot.used, 0].max
      )
    end

    # Upsert subscription_period_licenses based on current plan
    @subscription.plan.plan_licenses.includes(:license_type).each do |pl|
      spl = period.subscription_period_licenses
                  .find_or_initialize_by(license_type_id: pl.license_type_id)
      spl.update!(quantity: pl.quantity)
    end

    # Remove licenses that no longer exist in the new plan
    current_license_type_ids = @subscription.plan.plan_licenses.pluck(:license_type_id)
    period.subscription_period_licenses
          .where.not(license_type_id: current_license_type_ids)
          .destroy_all
  end

  def extract_extra_packages(period)
    period.subscription_period_credits
          .where("extra_packages > 0")
          .each_with_object({}) do |spc, hash|
      hash[spc.credit_type_id.to_s] = spc.extra_packages
    end
  end

  def serialize_gateways
    PaymentGateway.active.map { |gw| { id: gw.id, provider: gw.provider } }
  end

  def serialize_currencies
    Currency.active.map { |cur| { id: cur.id, code: cur.code, name: cur.name, symbol: cur.symbol } }
  end

  def serialize_available_integrations
    used_integration_ids = @customer.subscriptions.active.pluck(:integration_id)
    Integration.active
               .where.not(id: used_integration_ids)
               .map { |i| { id: i.id, name: i.name } }
  end

  def serialize_linked_integration(integration)
    return nil unless integration

    { id: integration.id, name: integration.name }
  end
end
