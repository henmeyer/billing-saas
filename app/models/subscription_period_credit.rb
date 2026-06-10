class SubscriptionPeriodCredit < ApplicationRecord
  belongs_to :subscription_period
  belongs_to :credit_type

  validates :quantity,       numericality: { greater_than_or_equal_to: 0 }
  validates :base,           numericality: { greater_than_or_equal_to: 0 }
  validates :extras,         numericality: { greater_than_or_equal_to: 0 }
  validates :extra_packages, numericality: { greater_than_or_equal_to: 0 }
end
