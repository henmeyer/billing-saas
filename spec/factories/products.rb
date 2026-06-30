FactoryBot.define do
  factory :product do
    account
    name          { Faker::Commerce.product_name }
    product_type  { "one_time" }
    pricing_model { "flat" }
    active        { true }

    trait :credit_pack do
      product_type    { "credit_pack" }
      credit_quantity { 1000 }
      credit_type     { association :credit_type, account: account }
    end
  end
end
