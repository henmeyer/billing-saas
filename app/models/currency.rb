class Currency < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_prices
  has_many :product_prices
  has_many :customers
  has_many :subscriptions

  validates :code,   presence: true, uniqueness: { scope: :account_id }
  validates :name,   presence: true
  validates :symbol, presence: true

  scope :active,  -> { where(active: true) }

  before_save :ensure_single_default

  def self.default_for_account
    active.find_by(default: true) || active.first
  end

  def format(amount_cents)
    amount = amount_cents / 100.0
    "#{symbol} #{format('%.2f', amount).gsub('.', ',')}"
  end

  private

  def ensure_single_default
    if default_changed? && default?
      Currency.where(account: account).where.not(id: id).update_all(default: false)
    end
  end
end
