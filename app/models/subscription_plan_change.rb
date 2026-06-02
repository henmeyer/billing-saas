class SubscriptionPlanChange < ApplicationRecord
  belongs_to :subscription
  belongs_to :from_plan, class_name: "Plan"
  belongs_to :to_plan,   class_name: "Plan"
end
