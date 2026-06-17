FactoryBot.define do
  factory :plan do
    transient do
      price_cents { 19_700 }
    end

    account
    name          { Faker::Commerce.product_name }
    billing_cycle { "monthly" }
    pricing_model { "flat" }
    active        { true }

    trait :per_unit do
      pricing_model { "per_unit" }
      after(:create) do |plan|
        lt       = create(:license_type, account: plan.account)
        currency = create(:currency, account: plan.account)
        plan.update!(pricing_license_type: lt)
        create(:plan_price, plan: plan, currency: currency, amount_cents: 4990)
      end
    end

    trait :volume do
      pricing_model { "volume" }
      after(:create) do |plan|
        lt       = create(:license_type, account: plan.account)
        currency = create(:currency, account: plan.account)
        plan.update!(pricing_license_type: lt)
        create(:plan_pricing_tier, plan: plan, currency: currency,
               from_unit: 1,  to_unit: 5,   unit_amount_cents: 4990, position: 0)
        create(:plan_pricing_tier, plan: plan, currency: currency,
               from_unit: 6,  to_unit: 10,  unit_amount_cents: 4590, position: 1)
        create(:plan_pricing_tier, plan: plan, currency: currency,
               from_unit: 11, to_unit: nil, unit_amount_cents: 3990, position: 2)
      end
    end
  end
end
