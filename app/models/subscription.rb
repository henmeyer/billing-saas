class Subscription < ApplicationRecord
  belongs_to :customer
  belongs_to :plan
  belongs_to :currency, optional: true

  has_many :subscription_periods, dependent: :destroy
  has_many :charges
  has_many :subscription_plan_changes

  STATUSES = %w[active past_due cancelled trialing].freeze
  GATEWAYS = %w[stripe asaas dlocal_go].freeze

  validates :status,  inclusion: { in: STATUSES }
  validates :gateway, inclusion: { in: GATEWAYS }

  scope :active, -> { where(status: %w[active trialing]) }

  def current_period
    subscription_periods.current.last
  end

  def effective_currency
    currency || customer.effective_currency
  end

  def price_in_currency
    plan.price_for(effective_currency)
  end

  def base_price_in_reais
    base_price_cents / 100.0
  end

  def current_period_amount
    current_period&.amount_cents || base_price_cents
  end

  def current_period_amount_in_reais
    current_period_amount / 100.0
  end

  def gateway_adapter
    Gateways::Base.for(gateway)
  end

  def cancel!
    gateway_adapter.cancel_subscription(gateway_subscription_id)
    update!(status: "cancelled", cancelled_at: Time.current)
    WebhookDispatchJob.perform_later(customer, "subscription.cancelled", {})
  end

  def change_plan!(new_plan, changed_by:, reason: "admin_change")
    old_plan  = plan
    new_price = new_plan.price_for(effective_currency)

    gateway_adapter.update_subscription(
      gateway_subscription_id,
      new_plan,
      amount_cents: new_price
    )

    transaction do
      subscription_plan_changes.create!(
        from_plan:     old_plan,
        to_plan:       new_plan,
        reason:        reason,
        changed_by_id: changed_by.id
      )
      update!(plan: new_plan, base_price_cents: new_price)
    end

    WebhookDispatchJob.perform_later(customer, "plan.changed", {
                                       previous_plan: { id: old_plan.id, name: old_plan.name },
                                       new_plan:      { id: new_plan.id, name: new_plan.name }
                                     })
  end
end
