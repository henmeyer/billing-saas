class CreateCurrencies < ActiveRecord::Migration[7.1]
  def change
    create_table :currencies do |t|
      t.references :account,  null: false, foreign_key: true
      t.string :code,         null: false
      t.string :name,         null: false
      t.string :symbol,       null: false
      t.boolean :default,     null: false, default: false
      t.boolean :active,      null: false, default: true
      t.timestamps
    end
    add_index :currencies, [:account_id, :code], unique: true
  end
end
