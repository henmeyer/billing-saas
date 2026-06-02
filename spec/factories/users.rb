FactoryBot.define do
  factory :user do
    association :account
    name     { Faker::Name.name }
    email    { Faker::Internet.unique.email }
    password { "password123" }
    role     { "member" }

    trait :admin do
      role { "admin" }
    end

    trait :owner do
      role { "owner" }
    end
  end
end
