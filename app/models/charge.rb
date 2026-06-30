class Charge < ApplicationRecord
  belongs_to :customer
  belongs_to :subscription

  STATUSES     = %w[pending paid failed refunded].freeze
  GATEWAYS     = %w[stripe asaas dlocal_go].freeze
  CHARGE_TYPES = %w[new_subscription renewal product plan_change].freeze

  enum :status,      STATUSES.zip(STATUSES).to_h, validate: true
  enum :charge_type, CHARGE_TYPES.zip(CHARGE_TYPES).to_h, validate: true, prefix: true

  validates :gateway,      inclusion: { in: GATEWAYS }
  validates :amount_cents, numericality: { greater_than: 0 }

  scope :paid,    -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }
  scope :failed,  -> { where(status: "failed") }
end
