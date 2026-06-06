class PlanIntegration < ApplicationRecord
  belongs_to :plan
  belongs_to :integration
end
