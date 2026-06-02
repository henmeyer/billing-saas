class LicenseType < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_licenses
  has_many :plans, through: :plan_licenses

  validates :key,   presence: true, uniqueness: { scope: :account_id }
  validates :label, presence: true
  validates :unit,  presence: true
end
