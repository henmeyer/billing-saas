class SubscriptionsController < ApplicationController
  before_action :set_customer, except: [:index]
  before_action :set_subscription, only: [:edit, :update, :destroy]
  before_action :require_admin!

  def index
    subscriptions = Subscription
                    .includes(:customer, :plan, :currency, plan: :plan_prices)
                    .order(created_at: :desc)

    render inertia: "Subscriptions/Index", props: {
      subscriptions: subscriptions.map { |sub| serialize_subscription_row(sub) },
      customers:     Customer.order(:name).map { |c| { id: c.id, name: c.name } }
    }
  end

  def new
    render inertia: "Subscriptions/Form", props: {
      customer:            serialize_customer(@customer),
      subscription:        {},
      plans:               serialize_plans,
      gateways:            serialize_gateways,
      currencies:          serialize_currencies,
      default_currency_id: @customer.effective_currency&.id,
      errors:              {}
    }
  end

  def create
    result = Subscriptions::CreateService.call(
      customer:                @customer,
      plan_id:                 params[:plan_id],
      gateway:                 params[:gateway],
      currency_id:             params[:currency_id],
      started_at:              params[:started_at] || Time.current,
      gateway_subscription_id: params[:gateway_subscription_id],
      extra_packages:          params[:extra_packages]&.to_unsafe_h || {}
    )

    if result.success?
      redirect_to customer_path(@customer), notice: "Assinatura criada com sucesso."
    else
      render inertia: "Subscriptions/Form", props: {
        customer:            serialize_customer(@customer),
        subscription:        params.permit(:plan_id, :gateway, :currency_id),
        plans:               serialize_plans,
        gateways:            serialize_gateways,
        currencies:          serialize_currencies,
        default_currency_id: @customer.effective_currency&.id,
        errors:              result.errors
      }
    end
  end

  def edit
    render inertia: "Subscriptions/Form", props: {
      customer:            serialize_customer(@customer),
      subscription:        serialize_subscription(@subscription),
      plans:               serialize_plans,
      gateways:            serialize_gateways,
      currencies:          serialize_currencies,
      default_currency_id: @customer.effective_currency&.id,
      errors:              {}
    }
  end

  def update
    if params[:plan_id].present? && params[:plan_id].to_i != @subscription.plan_id
      new_plan = Plan.find(params[:plan_id])
      @subscription.change_plan!(new_plan, changed_by: current_user)
    end

    extra_packages = params[:extra_packages]&.to_unsafe_h || {}

    @subscription.update!(
      status:   params[:status] || @subscription.status,
      metadata: @subscription.metadata.merge("extra_packages" => extra_packages)
    )

    update_credit_snapshots_for_extras(extra_packages) if extra_packages.present?

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
    {
      id:                      sub.id,
      plan_id:                 sub.plan_id,
      gateway:                 sub.gateway,
      gateway_subscription_id: sub.gateway_subscription_id,
      status:                  sub.status,
      currency_id:             sub.currency_id,
      currency_code:           sub.currency&.code,
      price_in_currency:       sub.price_in_currency,
      started_at:              sub.started_at&.strftime("%Y-%m-%d"),
      current_period_end:      sub.current_period_end&.strftime("%Y-%m-%d"),
      extra_packages:          sub.metadata["extra_packages"] || {}
    }
  end

  def serialize_subscription_row(sub)
    {
      id:                 sub.id,
      status:             sub.status,
      gateway:            sub.gateway,
      plan_name:          sub.plan&.name,
      price_cents:        sub.price_in_currency,
      billing_cycle:      sub.plan&.billing_cycle,
      currency_code:      sub.currency&.code,
      current_period_end: sub.current_period_end&.strftime("%d/%m/%Y"),
      started_at:         sub.started_at&.strftime("%d/%m/%Y"),
      customer:           { id: sub.customer.id, name: sub.customer.name }
    }
  end

  def serialize_plans
    Plan.active
        .includes(:plan_pricing_tiers, :plan_credits, plan_prices:  :currency,
                                                      plan_credits: :credit_type)
        .map do |plan|
      {
        id:                   plan.id,
        name:                 plan.name,
        billing_cycle:        plan.billing_cycle,
        pricing_model:        plan.pricing_model,
        pricing_metric_label: plan.pricing_metric_label,
        prices:               plan.plan_prices.map do |pp|
          { currency_id: pp.currency_id, amount_cents: pp.amount_cents }
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
            credit_type_label:      pc.credit_type&.label,
            credit_type_key:        pc.credit_type&.key,
            unit:                   pc.credit_type&.unit,
            base_quantity:          pc.quantity,
            allow_extras:           pc.allow_extras,
            extra_unit_size:        pc.extra_unit_size,
            extra_unit_price_cents: pc.extra_unit_price_cents
          }
        end
      }
    end
  end

  def update_credit_snapshots_for_extras(extra_packages)
    period = @subscription.current_period
    return unless period

    @subscription.plan.plan_credits.each do |pc|
      snapshot = period.credit_snapshots.find_by(credit_type_id: pc.credit_type_id)
      next unless snapshot

      n_packages = extra_packages[pc.credit_type_id.to_s].to_i
      new_limit  = pc.total_quantity(n_packages)
      snapshot.update!(
        limit:   new_limit,
        balance: [new_limit - snapshot.used, 0].max
      )
    end
  end

  def serialize_gateways
    PaymentGateway.active.map { |gw| { id: gw.id, provider: gw.provider } }
  end

  def serialize_currencies
    Currency.active.map { |cur| { id: cur.id, code: cur.code, name: cur.name, symbol: cur.symbol } }
  end
end
