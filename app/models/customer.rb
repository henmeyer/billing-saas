class Customer < ApplicationRecord
  acts_as_tenant :account

  belongs_to :currency, optional: true

  has_many :subscriptions
  has_many :charges
  has_many :credit_alerts
  has_many :customer_identities, dependent: :destroy
  has_many :integrations,        through: :customer_identities

  STATUSES = %w[active suspended churned trial].freeze

  validates :name,   presence: true
  validates :email,  presence: true, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }

  scope :active,  -> { where(status: "active") }
  scope :churned, -> { where(status: "churned") }
  scope :at_risk, -> { where("health_score < ?", 40) }

  def external_id_for(integration)
    customer_identities.find_by(integration: integration)&.external_id
  end

  def set_identity!(integration:, external_id:)
    identity = customer_identities.find_or_initialize_by(integration: integration)
    identity.update!(external_id: external_id)
  end

  def external_id
    customer_identities.first&.external_id
  end

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
