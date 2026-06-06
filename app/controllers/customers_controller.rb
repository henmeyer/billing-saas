class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update]

  def index
    customers = Customer.includes(:subscriptions)
                        .order(name: :asc)
                        .map { |c| serialize_customer(c) }

    render inertia: 'Customers/Index', props: { customers: }
  end

  def show
    subscription = @customer.active_subscription
    charges      = @customer.charges.order(created_at: :desc).limit(10)
    snapshots    = @customer.current_period
                            &.credit_snapshots
                            &.includes(:credit_type) || []

    render inertia: 'Customers/Show', props: {
      customer:     serialize_customer(@customer),
      subscription: subscription ? serialize_subscription(subscription) : nil,
      charges:      charges.map { |c| serialize_charge(c) },
      snapshots:    snapshots.map { |s| serialize_snapshot(s) }
    }
  end

  def new
    render inertia: 'Customers/Form', props: {
      customer: {}, errors: {}
    }
  end

  def create
    customer = Customer.new(customer_params)
    if customer.save
      redirect_to customer_path(customer), notice: 'Cliente criado.'
    else
      render inertia: 'Customers/Form', props: {
        customer: customer_params,
        errors:   customer.errors.as_json
      }
    end
  end

  def edit
    render inertia: 'Customers/Form', props: {
      customer: serialize_customer(@customer),
      errors:   {}
    }
  end

  def update
    if @customer.update(customer_params)
      redirect_to customer_path(@customer), notice: 'Cliente atualizado.'
    else
      render inertia: 'Customers/Form', props: {
        customer: serialize_customer(@customer).merge(customer_params),
        errors:   @customer.errors.as_json
      }
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name, :email, :document, :phone, :external_id, :status, :notes
    )
  end

  def serialize_customer(c)
    sub = c.subscriptions.first
    {
      id:           c.id,
      name:         c.name,
      email:        c.email,
      document:     c.document,
      phone:        c.phone,
      external_id:  c.external_id,
      status:       c.status,
      health_score: c.health_score,
      notes:        c.notes,
      plan_name:    sub&.plan&.name,
      gateway:      sub&.gateway,
      sub_status:   sub&.status,
    }
  end

  def serialize_subscription(sub)
    {
      id:                 sub.id,
      status:             sub.status,
      gateway:            sub.gateway,
      plan_name:          sub.plan.name,
      price:              sub.plan.price_in_reais,
      current_period_end: sub.current_period_end&.strftime('%d/%m/%Y'),
      started_at:         sub.started_at&.strftime('%d/%m/%Y'),
    }
  end

  def serialize_charge(c)
    {
      id:       c.id,
      amount:   c.amount_cents / 100.0,
      status:   c.status,
      gateway:  c.gateway,
      due_date: c.due_date&.strftime('%d/%m/%Y'),
      paid_at:  c.paid_at&.strftime('%d/%m/%Y'),
    }
  end

  def serialize_snapshot(s)
    {
      credit_type_key:   s.credit_type.key,
      credit_type_label: s.credit_type.label,
      credit_type_unit:  s.credit_type.unit,
      used:              s.used,
      limit:             s.limit,
      balance:           s.balance,
      usage_percent:     s.usage_percent,
    }
  end
end
