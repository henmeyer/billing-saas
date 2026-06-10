FactoryBot.define do
  factory :customer_identity do
    customer
    integration
    external_id { "EXT_#{SecureRandom.hex(4)}" }
  end
end
