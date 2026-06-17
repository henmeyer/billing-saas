FactoryBot.define do
  factory :plan_price do
    plan
    currency
    amount_cents { 19_700 }
  end
end
