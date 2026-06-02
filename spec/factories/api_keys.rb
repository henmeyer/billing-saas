FactoryBot.define do
  factory :api_key do
    association :account
    name         { Faker::App.name }
    token_digest { Digest::SHA256.hexdigest("billing_#{SecureRandom.hex(32)}") }
    last_four    { "abcd" }
    active       { true }
  end
end
