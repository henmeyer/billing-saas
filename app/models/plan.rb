class Plan < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_licenses, dependent: :destroy
  has_many :license_types, through: :plan_licenses
  has_many :plan_credits,  dependent: :destroy
  has_many :credit_types,  through: :plan_credits
  has_many :subscriptions

  BILLING_CYCLES = %w[monthly yearly custom].freeze

  validates :name,          presence: true
  validates :price_cents,   numericality: { greater_than_or_equal_to: 0 }
  validates :billing_cycle, inclusion: { in: BILLING_CYCLES }

  scope :active,   -> { where(active: true, archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def price_in_reais
    price_cents / 100.0
  end

  def archive!
    update!(active: false, archived_at: Time.current)
  end
end
