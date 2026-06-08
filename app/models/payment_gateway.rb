class PaymentGateway < ApplicationRecord
  acts_as_tenant :account

  PROVIDERS = %w[stripe asaas dlocal].freeze

  validates :provider, inclusion:  { in: PROVIDERS },
                       uniqueness: { scope: :account_id }
  validates :api_key_enc, presence: true

  scope :active, -> { where(active: true) }

  def api_key
    Rails.application.message_verifier(:gateway_keys).verify(api_key_enc)
  end

  def api_key=(raw_key)
    self.api_key_enc = Rails.application.message_verifier(:gateway_keys)
                            .generate(raw_key)
  end

  def secret_key
    return nil unless gateway_data["secret_key_enc"].present?

    Rails.application.message_verifier(:gateway_keys)
         .verify(gateway_data["secret_key_enc"])
  end

  def secret_key=(raw)
    gateway_data["secret_key_enc"] =
      Rails.application.message_verifier(:gateway_keys).generate(raw)
  end
end
