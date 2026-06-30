class ProductIntegration < ApplicationRecord
  belongs_to :product
  belongs_to :integration

  validates :product_id, uniqueness: { scope: :integration_id }
end
