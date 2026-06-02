FactoryBot.define do
  factory :plan do
    association :account
    name          { Faker::Commerce.product_name }
    price_cents   { 9900 }
    billing_cycle { "monthly" }
    active        { true }
  end
end
