class CreateCustomerIdentities < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_identities do |t|
      t.references :customer,    null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.string  :external_id,    null: false
      t.jsonb   :metadata,       null: false, default: {}
      t.timestamps
    end
    add_index :customer_identities,
              [:integration_id, :external_id],
              unique: true,
              name: "idx_customer_identities_integration_external"
    add_index :customer_identities,
              [:customer_id, :integration_id],
              unique: true,
              name: "idx_customer_identities_customer_integration"
  end
end
