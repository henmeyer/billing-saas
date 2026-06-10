class RemoveExternalIdFromCustomers < ActiveRecord::Migration[7.1]
  class MigrationCustomer < ApplicationRecord
    self.table_name = "customers"
    belongs_to :account
  end

  class MigrationIntegration < ApplicationRecord
    self.table_name = "integrations"
    scope :active, -> { where(active: true) }
  end

  class MigrationAccount < ApplicationRecord
    self.table_name = "accounts"
    has_many :integrations, class_name: "RemoveExternalIdFromCustomers::MigrationIntegration",
                            foreign_key: :account_id
  end

  class MigrationCustomerIdentity < ApplicationRecord
    self.table_name = "customer_identities"
  end

  def up
    MigrationCustomer.where.not(external_id: nil).find_each do |customer|
      account     = MigrationAccount.find(customer.account_id)
      integration = account.integrations.active.first
      next unless integration

      MigrationCustomerIdentity.find_or_create_by!(
        customer_id:    customer.id,
        integration_id: integration.id,
        external_id:    customer.external_id
      )
    end

    remove_column :customers, :external_id, :string
  end

  def down
    add_column :customers, :external_id, :string
  end
end
