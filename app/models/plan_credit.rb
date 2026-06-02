class PlanCredit < ApplicationRecord
  belongs_to :plan
  belongs_to :credit_type

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
end
