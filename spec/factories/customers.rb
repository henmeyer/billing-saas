FactoryBot.define do
  factory :customer do
    association :account
    name        { Faker::Name.name }
    email       { Faker::Internet.unique.email }
    document    { Faker::Company.brazilian_company_number(formatted: true) }
    status      { "active" }
  end
end
