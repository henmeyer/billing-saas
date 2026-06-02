class CreatePlanCredits < ActiveRecord::Migration[7.1]
  def change
    create_table :plan_credits do |t|
      t.references :plan,        null: false, foreign_key: true
      t.references :credit_type, null: false, foreign_key: true
      t.integer :quantity,       null: false, default: 0
      t.boolean :rollover,       null: false, default: false
      t.timestamps
    end
    add_index :plan_credits, [:plan_id, :credit_type_id], unique: true
  end
end
