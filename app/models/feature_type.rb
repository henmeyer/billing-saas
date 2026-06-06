class FeatureType < ApplicationRecord
  acts_as_tenant :account

  has_many :integration_field_configs
  has_many :integrations, through: :integration_field_configs
  has_many :plan_features
  has_many :plans, through: :plan_features

  validates :key,   presence: true, uniqueness: { scope: :account_id }
  validates :label, presence: true
end
