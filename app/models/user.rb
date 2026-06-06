class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users

  validates :name, presence: true

  def superadmin? = false

  def role_for(account)
    account_users.find_by(account: account)&.role
  end

  def admin_of?(account)
    role_for(account).in?(%w[owner admin])
  end

  def owner_of?(account)
    role_for(account) == "owner"
  end
end
