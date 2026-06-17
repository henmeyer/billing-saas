class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users

  validates :name, presence: true

  def superadmin? = false

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
end
