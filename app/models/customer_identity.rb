class CustomerIdentity < ApplicationRecord
  belongs_to :customer
  belongs_to :integration

  validates :external_id, presence:   true,
                          uniqueness: { scope: :integration_id }

  def self.find_customer(integration:, external_id:)
    find_by(integration: integration, external_id: external_id)&.customer
  end
end
