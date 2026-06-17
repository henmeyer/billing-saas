class PlanCredit < ApplicationRecord
  belongs_to :plan
  belongs_to :credit_type

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :extra_unit_size,
            numericality: { greater_than: 0 },
            if:           :allow_extras?
  validates :extra_unit_price_cents,
            numericality: { greater_than: 0 },
            if:           :allow_extras?

  def extras_cost(extra_packages)
    return 0 unless allow_extras?
    return 0 if extra_packages <= 0

    extra_packages * extra_unit_price_cents
  end

  def extras_quantity(extra_packages)
    return 0 unless allow_extras?

    extra_packages * extra_unit_size
  end

  def total_quantity(extra_packages = 0)
    quantity + extras_quantity(extra_packages)
  end

  def extra_unit_price_in_reais
    extra_unit_price_cents / 100.0
  end
end
