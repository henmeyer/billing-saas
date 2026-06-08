FactoryBot.define do
  factory :license_type do
    account
    key   { "#{Faker::Lorem.unique.word}_licenses" }
    label { Faker::Lorem.word.capitalize }
    unit  { "usuário" }
  end
end
