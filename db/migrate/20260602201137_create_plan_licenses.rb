class CreatePlanLicenses < ActiveRecord::Migration[7.1]
  def change
    create_table :plan_licenses do |t|
      t.references :plan,         null: false, foreign_key: true
      t.references :license_type, null: false, foreign_key: true
      t.integer :quantity,        null: false, default: 0
      t.timestamps
    end
    add_index :plan_licenses, [:plan_id, :license_type_id], unique: true
  end
end
