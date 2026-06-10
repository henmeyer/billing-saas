FactoryBot.define do
  factory :plan_credit do
    association :plan
    association :credit_type
    quantity              { 1000 }
    allow_extras          { false }
    extra_unit_size       { nil }
    extra_unit_price_cents { nil }
  end
end
