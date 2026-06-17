class PortalSession < ApplicationRecord
  belongs_to :customer
  belongs_to :integration

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at,   presence: true

  TOKEN_TTL = 15.minutes

  scope :expired, -> { where("expires_at < ?", Time.current) }

  def self.generate!(customer:, integration:)
    token_raw = SecureRandom.urlsafe_base64(48)

    session = create!(
      customer:     customer,
      integration:  integration,
      token_digest: Digest::SHA256.hexdigest(token_raw),
      expires_at:   TOKEN_TTL.from_now
    )

    [session, token_raw]
  end

  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    find_by(token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  def self.cleanup_expired!
    expired.delete_all
  end

  def expired?
    expires_at < Time.current
  end

  def valid_session?
    !expired?
  end

  def touch_access!(ip: nil)
    update_columns(accessed_at: Time.current, ip_address: ip)
  end
end
