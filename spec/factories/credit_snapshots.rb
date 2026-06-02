FactoryBot.define do
  factory :credit_snapshot do
    association :subscription_period
    association :credit_type
    used      { 0 }
    limit     { 1000 }
    balance   { 1000 }
    usage_percent { 0.0 }
    synced_at { Time.current }
  end
end
