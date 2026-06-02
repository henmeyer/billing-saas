class CreateSubscriptionPlanChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :subscription_plan_changes do |t|
      t.references :subscription, null: false, foreign_key: true
      t.references :from_plan,    null: false, foreign_key: { to_table: :plans }
      t.references :to_plan,      null: false, foreign_key: { to_table: :plans }
      t.string  :reason
      t.integer :changed_by_id
      t.timestamps
    end
  end
end
