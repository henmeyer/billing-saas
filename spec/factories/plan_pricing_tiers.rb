FactoryBot.define do
  factory :plan_pricing_tier do
    plan
    currency
    from_unit         { 1 }
    to_unit           { 5 }
    unit_amount_cents { 4990 }
    position          { 0 }
  end
end
