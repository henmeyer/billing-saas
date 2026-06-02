class CreateSubscriptionPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :subscription_periods do |t|
      t.references :subscription, null: false, foreign_key: true
      t.datetime :period_start,   null: false
      t.datetime :period_end,     null: false
      t.timestamps
    end
    add_index :subscription_periods, [:subscription_id, :period_start],
              unique: true
  end
end
