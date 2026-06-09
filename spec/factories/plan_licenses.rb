FactoryBot.define do
  factory :plan_license do
    association :plan
    association :license_type
    quantity { 20 }
  end
end
