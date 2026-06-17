class Plan < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_licenses, dependent: :destroy
  has_many :license_types, through: :plan_licenses
  has_many :plan_credits,  dependent: :destroy
  has_many :credit_types,  through: :plan_credits
  has_many :plan_features,  dependent: :destroy
  has_many :feature_types,  through: :plan_features
  has_many :plan_integrations, dependent: :destroy
  has_many :integrations,      through: :plan_integrations
  has_many :subscriptions
  has_many :plan_prices,        dependent: :destroy
  has_many :currencies,         through: :plan_prices
  has_many :plan_pricing_tiers, dependent: :destroy

  belongs_to :pricing_license_type, class_name: "LicenseType", optional: true
  belongs_to :pricing_credit_type,  class_name: "CreditType",  optional: true

  accepts_nested_attributes_for :plan_licenses, allow_destroy: true
  accepts_nested_attributes_for :plan_credits,  allow_destroy: true

  BILLING_CYCLES  = %w[monthly yearly custom].freeze
  PRICING_MODELS  = %w[flat per_unit volume].freeze

  validates :name,          presence: true
  validates :billing_cycle, inclusion: { in: BILLING_CYCLES }
  validates :pricing_model, inclusion: { in: PRICING_MODELS }

  scope :active,   -> { where(active: true, archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def price_for(currency)
    plan_prices.find_by(currency: currency)&.amount_cents || 0
  end

  def price_in(currency)
    price_for(currency) / 100.0
  end

  def formatted_price_for(currency)
    currency.format(price_for(currency))
  end

  def calculate_price(quantity, currency)
    case pricing_model
    when "flat"     then price_for(currency)
    when "per_unit" then unit_price_for(currency) * quantity
    when "volume"
      tier = tier_for(quantity, currency)
      return price_for(currency) unless tier

      tier.unit_amount_cents * quantity
    end
  end

  def unit_price_for(currency)
    plan_prices.find_by(currency: currency)&.amount_cents || 0
  end

  def tier_for(quantity, currency)
    plan_pricing_tiers.where(currency: currency).ordered.find { |t| t.covers?(quantity) }
  end

  def pricing_metric_label
    return nil if pricing_model == "flat"

    pricing_license_type&.label || pricing_credit_type&.label
  end

  def current_quantity_for(customer)
    return 1 if pricing_model == "flat"

    if pricing_license_type
      customer.metadata.dig("license_usage", pricing_license_type.key).to_i
    elsif pricing_credit_type
      snapshot = customer.current_period&.credit_snapshots
                         &.find_by(credit_type: pricing_credit_type)
      snapshot&.used.to_i || 0
    else
      1
    end
  end

  def archive!
    update!(active: false, archived_at: Time.current)
  end
end
