class Charge < ApplicationRecord
  belongs_to :customer
  belongs_to :subscription

  STATUSES = %w[pending paid failed refunded].freeze
  GATEWAYS = %w[stripe asaas dlocal].freeze

  validates :status,       inclusion: { in: STATUSES }
  validates :gateway,      inclusion: { in: GATEWAYS }
  validates :amount_cents, numericality: { greater_than: 0 }

  scope :paid,    -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }
  scope :failed,  -> { where(status: "failed") }
end
