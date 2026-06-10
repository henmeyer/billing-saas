class CreateSubscriptionPeriodCredits < ActiveRecord::Migration[7.1]
  def change
    create_table :subscription_period_credits do |t|
      t.references :subscription_period, null: false, foreign_key: true
      t.references :credit_type,         null: false, foreign_key: true
      t.integer :quantity,       null: false
      t.integer :base,           null: false
      t.integer :extras,         null: false, default: 0
      t.integer :extra_packages, null: false, default: 0
      t.timestamps
    end

    add_index :subscription_period_credits,
              [:subscription_period_id, :credit_type_id],
              unique: true,
              name: "idx_sub_period_credits_unique"
  end
end
