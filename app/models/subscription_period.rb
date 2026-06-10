class SubscriptionPeriod < ApplicationRecord
  belongs_to :subscription
  has_many :credit_snapshots,             dependent: :destroy
  has_many :subscription_period_credits,  dependent: :destroy
  has_many :subscription_period_licenses, dependent: :destroy
  has_many :credit_types,   through: :subscription_period_credits
  has_many :license_types,  through: :subscription_period_licenses

  scope :current, lambda {
    where("period_start <= ? AND period_end >= ?", Time.current, Time.current)
  }

  def total_amount_in_reais
    amount_cents / 100.0
  end

  def extras_amount_in_reais
    extras_amount_cents / 100.0
  end

  def has_extras?
    extras_amount_cents > 0
  end

  def credits_for(credit_type)
    credit_snapshots.find_by(credit_type: credit_type)
  end

  def credit_limit_for(credit_type)
    subscription_period_credits.find_by(credit_type: credit_type)&.quantity || 0
  end

  def license_quantity_for(license_type)
    subscription_period_licenses.find_by(license_type: license_type)&.quantity || 0
  end
end
