class Product < ApplicationRecord
  acts_as_tenant :account

  PRODUCT_TYPES = %w[one_time recurring credit_pack].freeze

  belongs_to :credit_type,          optional: true
  belongs_to :pricing_license_type, class_name: "LicenseType", optional: true
  belongs_to :pricing_credit_type,  class_name: "CreditType",  optional: true
  has_many :product_prices,         dependent: :destroy
  has_many :currencies,             through: :product_prices
  has_many :product_pricing_tiers,  dependent: :destroy

  PRICING_MODELS = %w[flat per_unit volume].freeze

  validates :name,          presence: true
  validates :product_type,  inclusion: { in: PRODUCT_TYPES }
  validates :pricing_model, inclusion: { in: PRICING_MODELS }

  scope :active, -> { where(active: true) }

  def price_for(currency)
    product_prices.find_by(currency: currency)&.amount_cents || 0
  end

  def price_in(currency)
    price_for(currency) / 100.0
  end

  def calculate_price(quantity, currency)
    case pricing_model
    when "flat"     then price_for(currency)
    when "per_unit" then price_for(currency) * quantity
    when "volume"
      tier = product_pricing_tiers.where(currency: currency).ordered.find { |t| t.covers?(quantity) }
      return price_for(currency) unless tier
      tier.unit_amount_cents * quantity
    end
  end
end
