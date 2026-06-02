class PlanLicense < ApplicationRecord
  belongs_to :plan
  belongs_to :license_type

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  def unlimited?
    quantity.zero?
  end
end
