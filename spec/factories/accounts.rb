FactoryBot.define do
  factory :account do
    name  { Faker::Company.name }
    slug  { Faker::Internet.unique.slug }
    status { "active" }
  end
end
