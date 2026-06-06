class PlanFeature < ApplicationRecord
  belongs_to :plan
  belongs_to :feature_type

  validates :enabled, inclusion: { in: [true, false] }
end
