FactoryBot.define do
  factory :credit_type do
    association :account
    key         { Faker::Alphanumeric.unique.alpha(number: 8) }
    label       { Faker::Commerce.product_name }
    unit        { "unidade" }
    reset_cycle { "billing_cycle" }
  end
end
