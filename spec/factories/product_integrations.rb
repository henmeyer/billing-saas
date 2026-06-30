FactoryBot.define do
  factory :product_integration do
    association :product
    association :integration
  end
end
