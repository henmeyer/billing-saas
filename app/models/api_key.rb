class ApiKey < ApplicationRecord
  acts_as_tenant :account

  validates :name,         presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :last_four,    presence: true

  scope :active, -> { where(active: true) }

  def self.generate!(account:, name:, expires_at: nil)
    token_raw = "billing_#{SecureRandom.hex(32)}"

    key = ActsAsTenant.with_tenant(account) do
      create!(
        name: name,
        token_digest: Digest::SHA256.hexdigest(token_raw),
        last_four: token_raw.last(4),
        expires_at: expires_at,
        active: true
      )
    end

    [key, token_raw]
  end

  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    digest = Digest::SHA256.hexdigest(raw_token)
    active.find_by(token_digest: digest)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def revoke!
    update!(active: false)
  end
end
