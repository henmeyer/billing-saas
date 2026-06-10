class Subscriptions::CreateService
  Result = Struct.new(:success?, :subscription, :errors)

  def self.call(**args) = new(**args).call

  def initialize(customer:, plan_id:, gateway:, integration_id:, currency_id: nil, started_at: Time.current,
                 gateway_subscription_id: nil, extra_packages: {}, initial_quantity: nil)
    @customer                = customer
    @plan                    = Plan.find(plan_id)
    @gateway                 = gateway
    @integration_id          = integration_id
    @currency                = Currency.find_by(id: currency_id) || customer.effective_currency
    @started_at              = started_at
    @gateway_subscription_id = gateway_subscription_id
    @extra_packages          = extra_packages
    @initial_quantity        = initial_quantity&.to_i.presence
  end

  def call
    errors = validate_integration
    return Result.new(false, nil, errors) if errors.any?

    ActiveRecord::Base.transaction do
      period_start = @started_at.to_time
      period_end   = period_start + 1.month

      pricing      = Pricing::CalculateService.call(
        plan:             @plan,
        customer:         @customer,
        currency:         @currency,
        extra_packages:   @extra_packages,
        initial_quantity: @initial_quantity
      )
      gw_sub_id    = @gateway_subscription_id.presence || create_gateway_subscription(pricing.amount_cents)
      base_price   = @plan.calculate_price(pricing.quantity, @currency)
      extras_total = [pricing.amount_cents - base_price, 0].max

      subscription = @customer.subscriptions.create!(
        plan:                    @plan,
        integration_id:          @integration_id,
        gateway:                 @gateway,
        currency:                @currency,
        gateway_subscription_id: gw_sub_id,
        status:                  "active",
        started_at:              period_start,
        current_period_start:    period_start,
        current_period_end:      period_end,
        base_price_cents:        base_price,
        currency_code:           @currency.code,
        metadata:                { extra_packages: @extra_packages }
      )

      period = subscription.subscription_periods.create!(
        period_start:        period_start,
        period_end:          period_end,
        amount_cents:        pricing.amount_cents,
        base_amount_cents:   base_price,
        extras_amount_cents: extras_total
      )

      create_period_records(period, pricing.extras_breakdown)

      WebhookDispatchJob.perform_later(
        @customer, "subscription.activated",
        { plan: { id: @plan.id, name: @plan.name } }
      )

      Result.new(true, subscription, [])
    end
  rescue ActiveRecord::RecordNotUnique
    Result.new(false, nil, ["Já existe assinatura ativa para este cliente nesta integração"])
  rescue StandardError => e
    Result.new(false, nil, [e.message])
  end

  private

  def validate_integration
    errors = []

    integration = Integration.find_by(id: @integration_id)

    if integration.nil?
      errors << "Integração não encontrada"
      return errors
    end

    unless integration.active?
      errors << "Integração não está ativa"
    end

    unless PlanIntegration.exists?(plan_id: @plan.id, integration_id: @integration_id)
      errors << "Plano não está disponível para esta integração"
    end

    errors
  end

  def create_period_records(period, extras_breakdown)
    create_period_credits(period, extras_breakdown)
    create_period_licenses(period)
  end

  def create_period_credits(period, extras_breakdown)
    @plan.plan_credits.includes(:credit_type).each do |pc|
      extra_item  = extras_breakdown&.find { |e| e[:credit_type_id] == pc.credit_type_id }
      base_qty    = pc.quantity
      extra_qty   = extra_item&.dig(:extra_quantity)  || 0
      n_packages  = extra_item&.dig(:extra_packages)  || 0
      total_qty   = base_qty + extra_qty

      period.subscription_period_credits.create!(
        credit_type:    pc.credit_type,
        quantity:       total_qty,
        base:           base_qty,
        extras:         extra_qty,
        extra_packages: n_packages
      )

      period.credit_snapshots.create!(
        credit_type: pc.credit_type,
        used:        0,
        limit:       total_qty,
        synced_at:   Time.current
      )
    end
  end

  def create_period_licenses(period)
    @plan.plan_licenses.includes(:license_type).each do |pl|
      period.subscription_period_licenses.create!(
        license_type: pl.license_type,
        quantity:     pl.quantity
      )
    end
  end

  def create_gateway_subscription(amount_cents)
    adapter = Gateways::Base.for(@gateway)
    adapter.create_customer(@customer) unless @customer.gateway_data[@gateway].present?
    result = adapter.create_subscription(@customer, @plan, amount_cents: amount_cents)
    result["id"] || result.id
  rescue Gateways::Base::GatewayError
    "manual_#{SecureRandom.hex(8)}"
  end
end
