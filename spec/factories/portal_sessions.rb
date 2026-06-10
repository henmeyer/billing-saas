FactoryBot.define do
  factory :portal_session do
    customer
    integration
    token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(48)) }
    expires_at { 15.minutes.from_now }
  end
end
