class Integration < ApplicationRecord
  acts_as_tenant :account

  AVAILABLE_EVENTS = %w[
    subscription.activated subscription.cancelled subscription.past_due
    subscription.renewed subscription.trial_ending plan.changed
    payment.received payment.failed credits.threshold_reached
    credits.depleted credits.recharged license.updated
  ].freeze

  validates :name,   presence: true
  validates :url,    presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :secret, presence: true

  has_many :integration_field_configs, dependent: :destroy
  has_many :license_types,  through: :integration_field_configs
  has_many :credit_types,   through: :integration_field_configs
  has_many :feature_types,  through: :integration_field_configs
  has_many :webhook_logs,         dependent: :destroy
  has_many :plan_integrations,    dependent: :destroy
  has_many :plans,                through: :plan_integrations
  has_many :integration_api_keys, dependent: :destroy
  has_many :customer_identities,  dependent: :destroy
  has_many :customers,            through: :customer_identities
  has_many :subscriptions

  scope :active, -> { where(active: true) }

  before_validation :generate_secret, on: :create

  def events_for(event_name)
    events.include?(event_name)
  end

  def active_license_types
    integration_field_configs
      .where(field_type: "license")
      .includes(:license_type)
      .map(&:license_type)
  end

  def active_credit_types
    integration_field_configs
      .where(field_type: "credit")
      .includes(:credit_type)
      .map(&:credit_type)
  end

  def active_feature_types
    integration_field_configs
      .where(field_type: "feature")
      .includes(:feature_type)
      .map(&:feature_type)
  end

  # Portal config helpers
  def portal_allow_plan_change?
    portal_config["allow_plan_change"] != false
  end

  def portal_allow_buy_products?
    portal_config["allow_buy_products"] != false
  end

  def portal_allow_adjust_extras?
    portal_config["allow_adjust_extras"] != false
  end

  def portal_show_invoice_history?
    portal_config["show_invoice_history"] != false
  end

  def portal_allow_cancel?
    portal_config["allow_cancel"] == true
  end

  private

  def generate_secret
    self.secret ||= SecureRandom.hex(32)
  end
end
