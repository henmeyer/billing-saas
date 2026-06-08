class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update]

  def index
    customers = Customer.includes(:subscriptions, :currency)
                        .order(name: :asc)
                        .map { |customer| serialize_customer(customer) }

    render inertia: "Customers/Index", props: { customers: }
  end

  def show
    subscription = @customer.active_subscription
    charges      = @customer.charges.order(created_at: :desc).limit(10)
    snapshots    = @customer.current_period&.credit_snapshots&.includes(:credit_type) || []
    currency     = @customer.effective_currency

    available_products = Product
                         .where(active: true, product_type: "credit_pack")
                         .includes(:credit_type, :product_prices)
                         .order(name: :asc)
                         .map do |prod|
      {
        id:              prod.id,
        name:            prod.name,
        price:           prod.price_in(currency),
        credit_quantity: prod.credit_quantity,
        credit_type:     prod.credit_type ? { unit: prod.credit_type.unit } : nil
      }
    end

    render inertia: "Customers/Show", props: {
      customer:           serialize_customer(@customer),
      subscription:       subscription ? serialize_subscription(subscription) : nil,
      charges:            charges.map { |charge| serialize_charge(charge) },
      snapshots:          snapshots.map { |snap| serialize_snapshot(snap) },
      available_products: available_products
    }
  end

  def new
    render inertia: "Customers/Form", props: {
      customer:   {},
      currencies: serialize_currencies,
      errors:     {}
    }
  end

  def create
    customer = Customer.new(customer_params)
    if customer.save
      redirect_to customer_path(customer), notice: "Cliente criado."
    else
      render inertia: "Customers/Form", props: {
        customer:   customer_params,
        currencies: serialize_currencies,
        errors:     customer.errors.as_json
      }
    end
  end

  def edit
    render inertia: "Customers/Form", props: {
      customer:   serialize_customer(@customer),
      currencies: serialize_currencies,
      errors:     {}
    }
  end

  def update
    if @customer.update(customer_params)
      redirect_to customer_path(@customer), notice: "Cliente atualizado."
    else
      render inertia: "Customers/Form", props: {
        customer:   serialize_customer(@customer).merge(customer_params),
        currencies: serialize_currencies,
        errors:     @customer.errors.as_json
      }
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name, :email, :document, :phone, :external_id, :status, :notes, :currency_id
    )
  end

  def serialize_customer(customer)
    sub = customer.subscriptions.first
    cur = customer.currency
    {
      id:           customer.id,
      name:         customer.name,
      email:        customer.email,
      document:     customer.document,
      phone:        customer.phone,
      external_id:  customer.external_id,
      status:       customer.status,
      health_score: customer.health_score,
      notes:        customer.notes,
      plan_name:    sub&.plan&.name,
      gateway:      sub&.gateway,
      sub_status:   sub&.status,
      currency_id:  customer.currency_id,
      currency:     cur ? { id: cur.id, code: cur.code, symbol: cur.symbol } : nil
    }
  end

  def serialize_subscription(sub)
    {
      id:                 sub.id,
      status:             sub.status,
      gateway:            sub.gateway,
      plan_name:          sub.plan.name,
      price:              sub.price_in_currency / 100.0,
      currency_code:      sub.effective_currency&.code,
      current_period_end: sub.current_period_end&.strftime("%d/%m/%Y"),
      started_at:         sub.started_at&.strftime("%d/%m/%Y")
    }
  end

  def serialize_charge(charge)
    {
      id:       charge.id,
      amount:   charge.amount_cents / 100.0,
      status:   charge.status,
      gateway:  charge.gateway,
      due_date: charge.due_date&.strftime("%d/%m/%Y"),
      paid_at:  charge.paid_at&.strftime("%d/%m/%Y")
    }
  end

  def serialize_currencies
    Currency.active.map do |cur|
      { id: cur.id, code: cur.code, name: cur.name, symbol: cur.symbol, default: cur.default }
    end
  end

  def serialize_snapshot(snap)
    {
      credit_type_key:   snap.credit_type.key,
      credit_type_label: snap.credit_type.label,
      credit_type_unit:  snap.credit_type.unit,
      used:              snap.used,
      limit:             snap.limit,
      balance:           snap.balance,
      usage_percent:     snap.usage_percent
    }
  end
end
