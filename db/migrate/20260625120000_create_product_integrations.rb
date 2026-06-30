class CreateProductIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :product_integrations do |t|
      t.references :product,     null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true

      t.timestamps
    end

    add_index :product_integrations, %i[product_id integration_id],
              unique: true,
              name:   "index_product_integrations_on_product_and_integration"
  end
end
