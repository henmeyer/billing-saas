FactoryBot.define do
  factory :subscription do
    association :customer
    association :plan
    association :integration
    status                  { "active" }
    gateway                 { "stripe" }
    gateway_subscription_id { "sub_#{SecureRandom.hex(8)}" }
    started_at              { 1.month.ago }
    current_period_start    { 1.day.ago }
    current_period_end      { 29.days.from_now }

    trait :asaas do
      gateway { "asaas" }
    end

    trait :dlocal_go do
      gateway { "dlocal_go" }
    end

    trait :past_due do
      status { "past_due" }
    end

    trait :cancelled do
      status       { "cancelled" }
      cancelled_at { Time.current }
    end
  end
end
