FactoryBot.define do
  factory :customer do
    association :account
    name        { Faker::Name.name }
    email       { Faker::Internet.unique.email }
    status      { "active" }
  end
end
