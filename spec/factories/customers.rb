FactoryBot.define do
  factory :customer do
    association :account
    name        { Faker::Name.name }
    email       { Faker::Internet.unique.email }
    external_id { Faker::Alphanumeric.unique.alphanumeric(number: 10) }
    status      { "active" }
  end
end
