class Product < ApplicationRecord
  acts_as_tenant :account

  PRODUCT_TYPES = %w[one_time recurring credit_pack].freeze

  belongs_to :credit_type,          optional: true
  belongs_to :pricing_license_type, class_name: "LicenseType", optional: true
  belongs_to :pricing_credit_type,  class_name: "CreditType",  optional: true
  has_many :product_prices,         dependent: :destroy
  has_many :currencies,             through: :product_prices
  has_many :product_pricing_tiers,  dependent: :destroy
  has_many :product_integrations,   dependent: :destroy
  has_many :integrations,           through: :product_integrations

  PRICING_MODELS = %w[flat per_unit volume].freeze

  validates :name,          presence: true
  validates :product_type,  inclusion: { in: PRODUCT_TYPES }
  validates :pricing_model, inclusion: { in: PRICING_MODELS }

  # credit_pack concede crédito de forma recorrente: exige tipo e quantidade.
  validates :credit_quantity, numericality: { greater_than: 0 }, if: :credit_pack?
  validate :credit_pack_requires_credit_type

  scope :active, -> { where(active: true) }

  def one_time?
    product_type == "one_time"
  end

  def credit_pack?
    product_type == "credit_pack"
  end

  # Concede crédito quando tem tipo de crédito vinculado (obrigatório em
  # credit_pack, opcional em one_time).
  def grants_credit?
    credit_type.present? && credit_quantity.to_i.positive?
  end

  def price_for(currency)
    product_prices.find_by(currency: currency)&.amount_cents || 0
  end

  def price_in(currency)
    price_for(currency) / 100.0
  end

  def calculate_price(quantity, currency)
    case pricing_model
    when "flat"     then price_for(currency) * quantity
    when "per_unit" then price_for(currency) * quantity
    when "volume"
      tier = product_pricing_tiers.where(currency: currency).ordered.find { |t| t.covers?(quantity) }
      return price_for(currency) unless tier

      tier.unit_amount_cents * quantity
    end
  end

  private

  def credit_pack_requires_credit_type
    return unless credit_pack?
    return if credit_type.present?

    errors.add(:credit_type_id, "é obrigatório para pacotes de crédito")
  end
end
