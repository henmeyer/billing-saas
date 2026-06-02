class CreditSnapshot < ApplicationRecord
  belongs_to :subscription_period
  belongs_to :credit_type

  validates :used,    numericality: { greater_than_or_equal_to: 0 }
  validates :limit,   numericality: { greater_than_or_equal_to: 0 }
  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  before_save :calculate_fields

  private

  def calculate_fields
    self.balance       = [limit - used, 0].max
    self.usage_percent = limit > 0 ? (used.to_f / limit * 100).round(1) : 0.0
  end
end
