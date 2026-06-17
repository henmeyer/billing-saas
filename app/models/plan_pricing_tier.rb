class PlanPricingTier < ApplicationRecord
  belongs_to :plan
  belongs_to :currency

  validates :from_unit,         presence:     true,
                                numericality: { greater_than: 0 }
  validates :unit_amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :position,          presence: true

  scope :ordered, -> { order(:position, :from_unit) }

  def unlimited?
    to_unit.nil?
  end

  def covers?(quantity)
    quantity >= from_unit && (unlimited? || quantity <= to_unit)
  end

  def label
    unlimited? ? "#{from_unit}+" : "#{from_unit}–#{to_unit}"
  end

  def unit_amount_in_base
    unit_amount_cents / 100.0
  end
end
