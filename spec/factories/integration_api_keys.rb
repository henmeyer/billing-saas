FactoryBot.define do
  factory :integration_api_key do
    integration
    name { "Test API Key" }

    transient do
      raw_token_value { "#{IntegrationApiKey::PREFIX}#{SecureRandom.hex(32)}" }
    end

    token_digest { Digest::SHA256.hexdigest(raw_token_value) }
    last_four { raw_token_value.last(4) }
    active { true }

    after(:build) do |key, evaluator|
      key.instance_variable_set(:@raw_token, evaluator.raw_token_value)
      key.define_singleton_method(:raw_token) { @raw_token }
    end
  end
end
