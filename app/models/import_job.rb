class ImportJob < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :user

  STATUSES = %w[pending fetching preview_ready importing done failed].freeze
  GATEWAYS = %w[asaas stripe].freeze

  validates :gateway, inclusion: { in: GATEWAYS }
  validates :status,  inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def pending?       = status == "pending"
  def fetching?      = status == "fetching"
  def preview_ready? = status == "preview_ready"
  def importing?     = status == "importing"
  def done?          = status == "done"
  def failed?        = status == "failed"

  def total_new
    preview["new"]&.length || 0
  end

  def total_duplicates
    preview["duplicates"]&.length || 0
  end

  def total_preview
    total_new + total_duplicates
  end
end
