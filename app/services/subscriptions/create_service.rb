class Subscriptions::CreateService
  Result = Struct.new(:success?, :subscription, :errors)

  def self.call(**args) = new(**args).call

  def initialize(customer:, plan_id:, gateway:, started_at: Time.current, gateway_subscription_id: nil)
    @customer                = customer
    @plan                    = Plan.find(plan_id)
    @gateway                 = gateway
    @started_at              = started_at
    @gateway_subscription_id = gateway_subscription_id
  end

  def call
    ActiveRecord::Base.transaction do
      period_start = @started_at.to_time
      period_end   = period_start + 1.month

      gw_sub_id = @gateway_subscription_id.presence || generate_gateway_subscription

      subscription = @customer.subscriptions.create!(
        plan:                    @plan,
        gateway:                 @gateway,
        gateway_subscription_id: gw_sub_id,
        status:                  "active",
        started_at:              period_start,
        current_period_start:    period_start,
        current_period_end:      period_end
      )

      subscription.subscription_periods.create!(
        period_start: period_start,
        period_end:   period_end
      )

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

  def generate_gateway_subscription
    "manual_#{SecureRandom.hex(8)}"
  end
end
