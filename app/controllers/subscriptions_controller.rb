class SubscriptionsController < ApplicationController
  before_action :set_customer, except: [:index]
  before_action :set_subscription, only: [:edit, :update, :destroy]
  before_action :require_admin!

  def index
    subscriptions = Subscription
                      .includes(:customer, :plan)
                      .order(created_at: :desc)

    render inertia: "Subscriptions/Index", props: {
      subscriptions: subscriptions.map { |s| serialize_subscription_row(s) }
    }
  end

  def new
    render inertia: "Subscriptions/Form", props: {
      customer:     serialize_customer(@customer),
      subscription: {},
      plans:        Plan.active.map { |p|
        { id: p.id, name: p.name, price: p.price_in_reais, billing_cycle: p.billing_cycle }
      },
      gateways: PaymentGateway.active.map { |g|
        { id: g.id, provider: g.provider }
      },
      errors: {}
    }
  end

  def create
    result = Subscriptions::CreateService.call(
      customer:   @customer,
      plan_id:    params[:plan_id],
      gateway:    params[:gateway],
      started_at: params[:started_at] || Time.current,
      gateway_subscription_id: params[:gateway_subscription_id]
    )

    if result.success?
      redirect_to customer_path(@customer), notice: "Assinatura criada com sucesso."
    else
      render inertia: "Subscriptions/Form", props: {
        customer:     serialize_customer(@customer),
        subscription: params.permit(:plan_id, :gateway),
        plans:        Plan.active.map { |p|
          { id: p.id, name: p.name, price: p.price_in_reais, billing_cycle: p.billing_cycle }
        },
        gateways: PaymentGateway.active.map { |g|
          { id: g.id, provider: g.provider }
        },
        errors: result.errors
      }
    end
  end

  def edit
    render inertia: "Subscriptions/Form", props: {
      customer:     serialize_customer(@customer),
      subscription: serialize_subscription(@subscription),
      plans:        Plan.active.map { |p|
        { id: p.id, name: p.name, price: p.price_in_reais, billing_cycle: p.billing_cycle }
      },
      gateways: PaymentGateway.active.map { |g|
        { id: g.id, provider: g.provider }
      },
      errors: {}
    }
  end

  def update
    if params[:plan_id].present? && params[:plan_id].to_i != @subscription.plan_id
      new_plan = Plan.find(params[:plan_id])
      @subscription.change_plan!(new_plan, changed_by: current_user)
    end

    @subscription.update!(status: params[:status] || @subscription.status)
    redirect_to customer_path(@customer), notice: "Assinatura atualizada."
  rescue => e
    redirect_to customer_path(@customer), alert: e.message
  end

  def destroy
    @subscription.cancel!
    redirect_to customer_path(@customer), notice: "Assinatura cancelada."
  rescue => e
    redirect_to customer_path(@customer), alert: e.message
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_subscription
    @subscription = @customer.subscriptions.find(params[:id])
  end

  def serialize_customer(c)
    { id: c.id, name: c.name, email: c.email }
  end

  def serialize_subscription(s)
    {
      id:                      s.id,
      plan_id:                 s.plan_id,
      gateway:                 s.gateway,
      gateway_subscription_id: s.gateway_subscription_id,
      status:                  s.status,
      started_at:              s.started_at&.strftime("%Y-%m-%d"),
      current_period_end:      s.current_period_end&.strftime("%Y-%m-%d"),
    }
  end

  def serialize_subscription_row(s)
    {
      id:                 s.id,
      status:             s.status,
      gateway:            s.gateway,
      plan_name:          s.plan&.name,
      price:              s.plan&.price_in_reais,
      billing_cycle:      s.plan&.billing_cycle,
      current_period_end: s.current_period_end&.strftime("%d/%m/%Y"),
      started_at:         s.started_at&.strftime("%d/%m/%Y"),
      customer: {
        id:   s.customer.id,
        name: s.customer.name,
      },
    }
  end

end
