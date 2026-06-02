class CreditType < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_credits
  has_many :plans, through: :plan_credits
  has_many :credit_snapshots
  has_many :credit_alerts

  RESET_CYCLES = %w[billing_cycle monthly yearly never].freeze

  validates :key,         presence: true, uniqueness: { scope: :account_id }
  validates :label,       presence: true
  validates :unit,        presence: true
  validates :reset_cycle, inclusion: { in: RESET_CYCLES }
end
