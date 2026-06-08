FactoryBot.define do
  factory :charge do
    customer
    subscription
    gateway           { "asaas" }
    gateway_charge_id { "pay_#{SecureRandom.hex(8)}" }
    amount_cents      { 19700 }
    status            { "paid" }
    paid_at           { Time.current }

    trait :pending do
      status  { "pending" }
      paid_at { nil }
    end

    trait :failed do
      status  { "failed" }
      paid_at { nil }
    end
  end
end
