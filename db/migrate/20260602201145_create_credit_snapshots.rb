class CreateCreditSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_snapshots do |t|
      t.references :subscription_period, null: false, foreign_key: true
      t.references :credit_type,         null: false, foreign_key: true
      t.integer :used,          null: false, default: 0
      t.integer :limit,         null: false, default: 0
      t.integer :balance,       null: false, default: 0
      t.float   :usage_percent, null: false, default: 0.0
      t.datetime :synced_at,    null: false
      t.timestamps
    end
    add_index :credit_snapshots,
              [:subscription_period_id, :credit_type_id],
              unique: true,
              name: "index_credit_snapshots_on_period_and_type"
  end
end
