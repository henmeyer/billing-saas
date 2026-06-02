class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :account

  ROLES = %w[owner admin member].freeze
  validates :role, inclusion: { in: ROLES }

  def owner?  = role == "owner"
  def admin?  = role.in?(%w[owner admin])
  def member? = role == "member"
end
