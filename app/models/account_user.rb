class AccountUser < ApplicationRecord
  belongs_to :account
  belongs_to :user

  ROLES = %w[owner admin manager seller member].freeze

  ROLE_LEVEL = {
    "owner"   => 50,
    "admin"   => 40,
    "manager" => 30,
    "seller"  => 20,
    "member"  => 10
  }.freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :account_id }

  def level
    ROLE_LEVEL[role] || 0
  end

  def at_least?(minimum_role)
    level >= ROLE_LEVEL[minimum_role.to_s]
  end

  def owner?   = role == "owner"
  def admin?   = at_least?(:admin)
  def manager? = at_least?(:manager)
  def seller?  = at_least?(:seller)
  def member?  = role == "member"
end
