class SubscriptionPeriod < ApplicationRecord
  belongs_to :subscription
  has_many :credit_snapshots, dependent: :destroy

  scope :current, lambda {
    where("period_start <= ? AND period_end >= ?", Time.current, Time.current)
  }

  def credits_for(credit_type)
    credit_snapshots.find_by(credit_type: credit_type)
  end
end
