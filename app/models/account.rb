class Account < ApplicationRecord
  has_many :users
  has_many :plans
  has_many :customers
  has_many :license_types
  has_many :credit_types
  has_many :integrations
  has_many :api_keys
  has_many :payment_gateways

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug ||= name.parameterize
  end
end
