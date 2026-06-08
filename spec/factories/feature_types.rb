FactoryBot.define do
  factory :feature_type do
    account
    key   { "#{Faker::Lorem.unique.word}_enabled" }
    label { Faker::Lorem.word.capitalize }
  end
end
