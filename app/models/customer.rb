class Customer < ApplicationRecord
  acts_as_tenant :account

  belongs_to :currency, optional: true

  has_many :subscriptions
  has_many :charges
  has_many :credit_alerts

  STATUSES = %w[active suspended churned trial].freeze

  validates :name,   presence: true
  validates :email,  presence: true, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }

  scope :active,  -> { where(status: "active") }
  scope :churned, -> { where(status: "churned") }
  scope :at_risk, -> { where("health_score < ?", 40) }

  def effective_currency
    currency || Currency.default_for_account
  end

  def active_subscription
    subscriptions.find_by(status: %w[active trialing past_due])
  end

  def current_period
    active_subscription&.subscription_periods&.current&.last
  end
end
