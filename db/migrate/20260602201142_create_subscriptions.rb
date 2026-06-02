class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :plan,     null: false, foreign_key: true
      t.string  :status,      null: false, default: "active"
      t.string  :gateway,     null: false
      t.string  :gateway_subscription_id
      t.datetime :started_at,            null: false
      t.datetime :trial_ends_at
      t.datetime :cancelled_at
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.timestamps
    end
    add_index :subscriptions, [:gateway, :gateway_subscription_id],
              unique: true,
              where: "gateway_subscription_id IS NOT NULL"
  end
end
