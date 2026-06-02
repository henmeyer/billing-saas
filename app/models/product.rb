class Product < ApplicationRecord
  acts_as_tenant :account

  PRODUCT_TYPES = %w[one_time recurring credit_pack].freeze

  belongs_to :credit_type, optional: true

  validates :name,         presence: true
  validates :price_cents,  numericality: { greater_than_or_equal_to: 0 }
  validates :product_type, inclusion: { in: PRODUCT_TYPES }

  scope :active, -> { where(active: true) }
end
