class CreateSubscriptionPeriodLicenses < ActiveRecord::Migration[7.1]
  def change
    create_table :subscription_period_licenses do |t|
      t.references :subscription_period, null: false, foreign_key: true
      t.references :license_type,        null: false, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps
    end

    add_index :subscription_period_licenses,
              [:subscription_period_id, :license_type_id],
              unique: true,
              name: "idx_sub_period_licenses_unique"
  end
end
