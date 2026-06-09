class Subscriptions::CreateService
  Result = Struct.new(:success?, :subscription, :errors)

  def self.call(**args) = new(**args).call

  def initialize(customer:, plan_id:, gateway:, currency_id: nil, started_at: Time.current,
                 gateway_subscription_id: nil, extra_packages: {})
    @customer                = customer
    @plan                    = Plan.find(plan_id)
    @gateway                 = gateway
    @currency                = Currency.find_by(id: currency_id) || customer.effective_currency
    @started_at              = started_at
    @gateway_subscription_id = gateway_subscription_id
    @extra_packages          = extra_packages
  end

  def call
    ActiveRecord::Base.transaction do
      period_start = @started_at.to_time
      period_end   = period_start + 1.month

      pricing   = Pricing::CalculateService.call(
        plan:           @plan,
        customer:       @customer,
        currency:       @currency,
        extra_packages: @extra_packages
      )
      gw_sub_id = @gateway_subscription_id.presence || create_gateway_subscription(pricing.amount_cents)

      subscription = @customer.subscriptions.create!(
        plan:                    @plan,
        gateway:                 @gateway,
        currency:                @currency,
        gateway_subscription_id: gw_sub_id,
        status:                  "active",
        started_at:              period_start,
        current_period_start:    period_start,
        current_period_end:      period_end,
        metadata:                { extra_packages: @extra_packages }
      )

      period = subscription.subscription_periods.create!(
        period_start: period_start,
        period_end:   period_end
      )

      create_credit_snapshots(period, pricing.extras_breakdown)

      WebhookDispatchJob.perform_later(
        @customer, "subscription.activated",
        { plan: { id: @plan.id, name: @plan.name } }
      )

      Result.new(true, subscription, [])
    end
  rescue StandardError => e
    Result.new(false, nil, [e.message])
  end

  private

  def create_credit_snapshots(period, extras_breakdown)
    @plan.plan_credits.each do |pc|
      extra_item = extras_breakdown&.find { |e| e[:credit_type_id] == pc.credit_type_id }
      total_quantity = extra_item ? extra_item[:total_quantity] : pc.quantity

      period.credit_snapshots.create!(
        credit_type: pc.credit_type,
        used:        0,
        limit:       total_quantity,
        synced_at:   Time.current
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
