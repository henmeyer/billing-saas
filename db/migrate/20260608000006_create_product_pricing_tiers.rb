class CreateProductPricingTiers < ActiveRecord::Migration[7.1]
  def change
    create_table :product_pricing_tiers do |t|
      t.references :product,  null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.integer :from_unit,          null: false
      t.integer :to_unit
      t.integer :unit_amount_cents,  null: false
      t.integer :position,           null: false, default: 0
      t.timestamps
    end

    add_index :product_pricing_tiers, [:product_id, :currency_id, :from_unit],
              unique: true, name: "idx_product_pricing_tiers_unique"
  end
end
