FactoryBot.define do
  factory :subscription_period do
    association :subscription
    period_start { 1.day.ago }
    period_end   { 29.days.from_now }
  end
end
