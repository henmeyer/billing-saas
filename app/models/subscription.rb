class Subscription < ApplicationRecord
  belongs_to :customer
  belongs_to :plan
  belongs_to :integration
  belongs_to :currency, optional: true

  has_many :subscription_periods, dependent: :destroy
  has_many :charges
  has_many :subscription_plan_changes

  STATUSES = %w[active past_due cancelled trialing pending].freeze
  GATEWAYS = %w[stripe asaas dlocal_go].freeze
  MANAGED_BY = %w[gateway billing].freeze

  validates :status,     inclusion: { in: STATUSES }
  validates :gateway,    inclusion: { in: GATEWAYS }, allow_nil: true
  validates :managed_by, inclusion: { in: MANAGED_BY }
  validates :integration_id, presence: true
  validate :unique_active_per_integration, on: :create

  scope :active, -> { where(status: %w[active trialing past_due]) }
  scope :trialing, -> { where(status: "trialing") }
  scope :trial_expiring_in, ->(days) { trialing.where(trial_ends_at: ..days.from_now) }
  scope :trial_expired, -> { trialing.where("trial_ends_at < ?", Time.current) }
  scope :gateway_managed, -> { where(managed_by: "gateway") }
  scope :billing_managed, -> { where(managed_by: "billing") }

  attr_readonly :integration_id

  after_update :dispatch_activation_webhook, if: :became_active?
  after_update :reset_period_on_activation, if: :became_active?

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

  def trialing?
    status == "trialing"
  end

  def pending?
    status == "pending"
  end

  def gateway_managed?
    managed_by == "gateway"
  end

  def billing_managed?
    managed_by == "billing"
  end

  def trial_expired?
    trialing? && trial_ends_at.present? && trial_ends_at < Time.current
  end

  def trial_days_remaining
    return nil unless trialing? && trial_ends_at.present?

    [(trial_ends_at.to_date - Date.current).to_i, 0].max
  end

  def convert_from_trial!(gateway:, gateway_subscription_id: nil)
    update!(
      status:                  "active",
      gateway:                 gateway,
      gateway_subscription_id: gateway_subscription_id,
      converted_at:            Time.current
    )
  end

  def cancel!
    gateway_adapter.cancel_subscription(gateway_subscription_id) if gateway.present?
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

  private

  # Garante o disparo de subscription.activated sempre que o status muda
  # para "active", não importa qual gateway ou fluxo causou a mudança
  # (criação direta, renovação, conversão de trial, sync manual, etc).
  def became_active?
    saved_change_to_status? && status == "active"
  end

  def dispatch_activation_webhook
    WebhookDispatchJob.perform_later(
      customer,
      "subscription.activated",
      {
        plan:                 { id: plan.id, name: plan.name },
        gateway:              gateway,
        converted_from_trial: status_before_last_save == "trialing"
      }
    )
  end

  # Quando a assinatura é ativada (vindo de trialing ou pending), recalcula
  # o fim do período para billing_cycle a partir de agora — a menos que o
  # caller já tenha atualizado current_period_end no mesmo save.
  def reset_period_on_activation
    return if saved_change_to_current_period_end?

    now        = Time.current
    period_end = case plan.billing_cycle
                 when "yearly" then now + 1.year
                 else               now + 1.month
                 end

    update_columns(
      current_period_start: now,
      current_period_end:   period_end
    )

    # Atualiza o período correspondente também
    current_sub_period = subscription_periods.order(created_at: :desc).first
    current_sub_period&.update_columns(
      period_start: now,
      period_end:   period_end
    )
  end

  def unique_active_per_integration
    return unless customer_id && integration_id

    existing = Subscription.where(customer_id: customer_id, integration_id: integration_id)
                           .where(status: %w[active trialing past_due pending])
    existing = existing.where.not(id: id) if persisted?

    return unless existing.exists?

    errors.add(:integration_id, "já possui assinatura ativa nesta integração")
  end
end
