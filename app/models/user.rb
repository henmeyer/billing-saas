class User < ApplicationRecord
  ACCEPTABLE_AVATAR_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_AVATAR_SIZE = 5.megabytes

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users
  has_one_attached :avatar

  validates :name, presence: true
  validate :acceptable_avatar, if: -> { avatar.attached? }

  def superadmin? = false

  def avatar_url
    return unless avatar.attached?

    Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: true)
  end

  def initials
    name.to_s.split.map(&:first).first(2).join.upcase
  end

  def role_for(account)
    account_user_for(account)&.role
  end

  def account_user_for(account)
    account_users.find_by(account: account)
  end

  def at_least?(role, account = ActsAsTenant.current_tenant)
    return true if superadmin?

    account_user_for(account)&.at_least?(role) || false
  end

  def owner?(account = ActsAsTenant.current_tenant)
    at_least?(:owner, account)
  end

  def admin?(account = ActsAsTenant.current_tenant)
    at_least?(:admin, account)
  end

  def manager?(account = ActsAsTenant.current_tenant)
    at_least?(:manager, account)
  end

  def seller?(account = ActsAsTenant.current_tenant)
    at_least?(:seller, account)
  end

  private

  def acceptable_avatar
    errors.add(:avatar, "deve ter no máximo 5MB") if avatar.blob.byte_size > MAX_AVATAR_SIZE

    return if ACCEPTABLE_AVATAR_TYPES.include?(avatar.blob.content_type)

    errors.add(:avatar, "deve ser JPEG, PNG ou WebP")
  end
end
