FactoryBot.define do
  factory :product do
    account
    name          { Faker::Commerce.product_name }
    product_type  { "one_time" }
    pricing_model { "flat" }
    active        { true }
  end
end
