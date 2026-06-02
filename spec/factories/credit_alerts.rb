FactoryBot.define do
  factory :credit_alert do
    association :customer
    association :credit_type
    threshold    { 80 }
    period_start { Time.current.beginning_of_month }
  end
end
