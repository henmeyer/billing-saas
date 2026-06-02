class PaymentGateway < ApplicationRecord
  acts_as_tenant :account

  PROVIDERS = %w[stripe asaas].freeze

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
end
