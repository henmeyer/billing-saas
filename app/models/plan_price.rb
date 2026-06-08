class PlanPrice < ApplicationRecord
  belongs_to :plan
  belongs_to :currency

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  def amount_in_base
    amount_cents / 100.0
  end
end
