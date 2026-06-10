FactoryBot.define do
  factory :product_price do
    product
    currency
    amount_cents { 5000 }
  end
end
