class IntegrationApiKey < ApplicationRecord
  belongs_to :integration

  validates :name,         presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :last_four,    presence: true

  scope :active, -> { where(active: true) }

  PREFIX = "billing_int_".freeze

  def self.generate!(integration:, name:, expires_at: nil)
    token_raw = "#{PREFIX}#{SecureRandom.hex(32)}"

    key = create!(
      integration:  integration,
      name:         name,
      token_digest: Digest::SHA256.hexdigest(token_raw),
      last_four:    token_raw.last(4),
      expires_at:   expires_at,
      active:       true
    )

    [key, token_raw]
  end

  def self.find_by_token(raw_token)
    return nil if raw_token.blank?
    return nil unless raw_token.start_with?(PREFIX)

    active.find_by(token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  def expired?          = expires_at.present? && expires_at < Time.current
  def revoke!           = update!(active: false)
  def touch_last_used!  = update_column(:last_used_at, Time.current)
end
