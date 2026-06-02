FactoryBot.define do
  factory :integration do
    association :account
    name   { Faker::App.name }
    url    { "https://example.com/webhooks" }
    secret { SecureRandom.hex(32) }
    active { true }
    events { ["payment.received"] }
  end
end
