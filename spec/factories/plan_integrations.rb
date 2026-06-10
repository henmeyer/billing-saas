FactoryBot.define do
  factory :plan_integration do
    association :plan
    association :integration
  end
end
