class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.references :account,       null: false, foreign_key: true
      t.string  :name,             null: false
      t.text    :description
      t.integer :price_cents,      null: false, default: 0
      t.string  :currency,         null: false, default: "BRL"
      t.string  :product_type,     null: false, default: "one_time"
      t.references :credit_type,   foreign_key: true
      t.integer :credit_quantity,  default: 0
      t.boolean :active,           null: false, default: true
      t.timestamps
    end
  end
end
