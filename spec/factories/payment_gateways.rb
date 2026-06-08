FactoryBot.define do
  factory :payment_gateway do
    account
    provider    { "asaas" }
    api_key_enc {
      Rails.application.message_verifier(:gateway_keys).generate("test_key_123")
    }
    active  { true }
    default { true }

    factory :stripe_gateway do
      provider { "stripe" }
    end

    factory :dlocal_gateway do
      provider { "dlocal" }
      gateway_data do
        {
          "secret_key_enc" => Rails.application.message_verifier(:gateway_keys)
                                   .generate("test_secret_123")
        }
      end
    end
  end
end
