class WebhookLog < ApplicationRecord
  belongs_to :integration
  belongs_to :customer

  STATUSES = %w[pending delivered failed].freeze

  validates :event,  presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :uuid,   presence: true, uniqueness: true

  scope :pending, -> { where(status: "pending") }
  scope :failed,  -> { where(status: "failed") }
  scope :due,     -> { pending.where("next_retry_at <= ?", Time.current) }
end
