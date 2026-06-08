class Subscription < ApplicationRecord
  belongs_to :customer
  belongs_to :plan
  belongs_to :currency, optional: true

  has_many :subscription_periods, dependent: :destroy
  has_many :charges
  has_many :subscription_plan_changes

  STATUSES = %w[active past_due cancelled trialing].freeze
  GATEWAYS = %w[stripe asaas].freeze

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

  def gateway_adapter
    Gateways::Base.for(gateway)
  end

  def cancel!
    gateway_adapter.cancel_subscription(gateway_subscription_id)
    update!(status: "cancelled", cancelled_at: Time.current)
    WebhookDispatchJob.perform_later(customer, "subscription.cancelled", {})
  end

  def change_plan!(new_plan, changed_by:, reason: "admin_change")
    old_plan = plan
    gateway_adapter.update_subscription(
      gateway_subscription_id,
      new_plan,
      amount_cents: new_plan.price_for(effective_currency)
    )

    transaction do
      subscription_plan_changes.create!(
        from_plan:     old_plan,
        to_plan:       new_plan,
        reason:        reason,
        changed_by_id: changed_by.id
      )
      update!(plan: new_plan)
    end

    WebhookDispatchJob.perform_later(customer, "plan.changed", {
                                       previous_plan: { id: old_plan.id, name: old_plan.name },
                                       new_plan:      { id: new_plan.id, name: new_plan.name }
                                     })
  end
end
