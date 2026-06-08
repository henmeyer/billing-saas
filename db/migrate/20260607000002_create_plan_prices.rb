class CreatePlanPrices < ActiveRecord::Migration[7.1]
  def change
    create_table :plan_prices do |t|
      t.references :plan,     null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.timestamps
    end
    add_index :plan_prices, [:plan_id, :currency_id], unique: true
  end
end
