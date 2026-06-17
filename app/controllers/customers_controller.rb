class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    customers = policy_scope(Customer).includes(:subscriptions, :currency)
                        .order(name: :asc)
                        .map { |customer| serialize_customer(customer) }

    render inertia: "Customers/Index", props: { customers: }
  end

  def show
    authorize @customer

    active_subscriptions = @customer.subscriptions
                                    .where(status: %w[active trialing past_due])
                                    .includes(:integration, :plan)
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

    period = @customer.current_period

    first_subscription = active_subscriptions.first

    render inertia: "Customers/Show", props: {
      customer:           serialize_customer(@customer),
      subscriptions:      active_subscriptions.map { |sub| serialize_subscription(sub) },
      subscription:       first_subscription ? serialize_subscription(first_subscription) : nil,
      charges:            charges.map { |charge| serialize_charge(charge) },
      snapshots:          snapshots.map { |snap| serialize_snapshot(snap) },
      available_products: available_products,
      period_credits:     serialize_period_credits(period),
      period_licenses:    serialize_period_licenses(period)
    }
  end

  def new
    authorize Customer

    render inertia: "Customers/Form", props: {
      customer:     {},
      currencies:   serialize_currencies,
      integrations: serialize_integrations,
      errors:       {}
    }
  end

  def create
    authorize Customer

    customer = Customer.new(customer_params)
    if customer.save
      sync_identities(customer)
      redirect_to customer_path(customer), notice: "Cliente criado."
    else
      render inertia: "Customers/Form", props: {
        customer:     customer_params,
        currencies:   serialize_currencies,
        integrations: serialize_integrations,
        errors:       customer.errors.as_json
      }
    end
  end

  def edit
    authorize @customer

    render inertia: "Customers/Form", props: {
      customer:     serialize_customer_for_form(@customer),
      currencies:   serialize_currencies,
      integrations: serialize_integrations,
      errors:       {}
    }
  end

  def update
    authorize @customer

    if @customer.update(customer_params)
      sync_identities(@customer)
      redirect_to customer_path(@customer), notice: "Cliente atualizado."
    else
      render inertia: "Customers/Form", props: {
        customer:     serialize_customer(@customer).merge(customer_params),
        currencies:   serialize_currencies,
        integrations: serialize_integrations,
        errors:       @customer.errors.as_json
      }
    end
  end

  def destroy
    authorize @customer

    @customer.destroy!
    redirect_to customers_path, notice: "Cliente removido."
  rescue ActiveRecord::InvalidForeignKey
    redirect_to customers_path, alert: "Não é possível remover — cliente possui assinaturas ou cobranças vinculadas."
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name, :email, :document, :phone, :status, :notes, :currency_id
    )
  end

  def sync_identities(customer)
    return unless params[:identities].present?

    params[:identities].each do |integration_id, external_id|
      next if external_id.blank?

      integration = Integration.find_by(id: integration_id)
      next unless integration

      identity = customer.customer_identities.find_or_initialize_by(integration: integration)
      identity.update!(external_id: external_id)
    end
  end

  def serialize_integrations
    Integration.active.map { |itg| { id: itg.id, name: itg.name, url: itg.url } }
  end

  def serialize_customer_for_form(customer)
    {
      id:          customer.id,
      name:        customer.name,
      email:       customer.email,
      document:    customer.document,
      phone:       customer.phone,
      status:      customer.status,
      notes:       customer.notes,
      currency_id: customer.currency_id,
      identities:  customer.customer_identities.includes(:integration).map { |ci|
        {
          id:               ci.id,
          integration_id:   ci.integration_id,
          integration_name: ci.integration.name,
          external_id:      ci.external_id
        }
      }
    }
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
    period = sub.current_period
    {
      id:                     sub.id,
      status:                 sub.status,
      gateway:                sub.gateway,
      integration_name:       sub.integration&.name,
      plan_name:              sub.plan.name,
      base_price_cents:       sub.base_price_cents,
      period_amount_cents:    period&.amount_cents || sub.base_price_cents,
      period_base_cents:      period&.base_amount_cents || sub.base_price_cents,
      period_extras_cents:    period&.extras_amount_cents || 0,
      has_extras:             (period&.extras_amount_cents || 0).positive?,
      currency_code:          sub.currency_code,
      current_period_end:     sub.current_period_end&.strftime("%d/%m/%Y"),
      started_at:             sub.started_at&.strftime("%d/%m/%Y"),
      current_extra_packages: period ? extract_extra_packages(period) : {}
    }
  end

  def serialize_charge(charge)
    {
      id:           charge.id,
      amount:       charge.amount_cents / 100.0,
      status:       charge.status,
      gateway:      charge.gateway,
      due_date:     charge.due_date&.strftime("%d/%m/%Y"),
      paid_at:      charge.paid_at&.strftime("%d/%m/%Y"),
      redirect_url: charge.redirect_url
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

  def serialize_period_credits(period)
    return [] unless period

    period.subscription_period_credits.includes(:credit_type).map do |spc|
      {
        credit_type_id:    spc.credit_type_id,
        credit_type_key:   spc.credit_type.key,
        credit_type_label: spc.credit_type.label,
        credit_type_unit:  spc.credit_type.unit,
        quantity:          spc.quantity,
        base:              spc.base,
        extras:            spc.extras,
        extra_packages:    spc.extra_packages
      }
    end
  end

  def serialize_period_licenses(period)
    return [] unless period

    period.subscription_period_licenses.includes(:license_type).map do |spl|
      used = @customer.metadata.dig("license_usage", spl.license_type.key).to_i
      {
        license_type_id:    spl.license_type_id,
        license_type_key:   spl.license_type.key,
        license_type_label: spl.license_type.label,
        license_type_unit:  spl.license_type.unit,
        quantity:           spl.quantity,
        unlimited:          spl.unlimited?,
        used:               used,
        available:          spl.unlimited? ? nil : [spl.quantity - used, 0].max
      }
    end
  end

  def extract_extra_packages(period)
    period.subscription_period_credits
          .where("extra_packages > 0")
          .each_with_object({}) do |spc, hash|
      hash[spc.credit_type_id.to_s] = spc.extra_packages
    end
  end
end
