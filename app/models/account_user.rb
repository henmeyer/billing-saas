class AccountUser < ApplicationRecord
  belongs_to :account
  belongs_to :user

  ROLES = %w[owner admin member].freeze
  validates :role, inclusion: { in: ROLES }

  def owner?  = role == "owner"
  def admin?  = role.in?(%w[owner admin])
  def member? = role == "member"
end
