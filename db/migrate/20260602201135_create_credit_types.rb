class CreateCreditTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key,          null: false
      t.string :label,        null: false
      t.string :unit,         null: false
      t.string :reset_cycle,  null: false, default: "billing_cycle"
      t.text   :description
      t.timestamps
    end
    add_index :credit_types, [:account_id, :key], unique: true
  end
end
