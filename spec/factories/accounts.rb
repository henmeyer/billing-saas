FactoryBot.define do
  factory :account do
    name   { Faker::Company.name }
    slug   { Faker::Internet.unique.slug }
    status { "active" }

    trait :with_defaults do
      after(:create) do |account|
        Seeds::DefaultTypesService.call(account)
      end
    end
  end
end
