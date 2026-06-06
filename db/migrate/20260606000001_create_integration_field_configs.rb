class CreateIntegrationFieldConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :integration_field_configs do |t|
      t.references :integration,  null: false, foreign_key: true
      t.references :license_type, foreign_key: true
      t.references :credit_type,  foreign_key: true
      t.string     :field_type,   null: false
      t.timestamps
    end

    add_index :integration_field_configs,
              [:integration_id, :license_type_id],
              unique: true,
              where: "license_type_id IS NOT NULL",
              name: "idx_integration_field_license"

    add_index :integration_field_configs,
              [:integration_id, :credit_type_id],
              unique: true,
              where: "credit_type_id IS NOT NULL",
              name: "idx_integration_field_credit"
  end
end
