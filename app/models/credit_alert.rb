class CreditAlert < ApplicationRecord
  belongs_to :customer
  belongs_to :credit_type

  THRESHOLDS = [80, 95, 100].freeze

  validates :threshold, inclusion: { in: THRESHOLDS }
end
