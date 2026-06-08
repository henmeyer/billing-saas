class CreateProductPrices < ActiveRecord::Migration[7.1]
  def change
    create_table :product_prices do |t|
      t.references :product,  null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.timestamps
    end
    add_index :product_prices, [:product_id, :currency_id], unique: true
  end
end
