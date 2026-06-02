class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.references :account,     null: false, foreign_key: true
      t.string  :name,           null: false
      t.string  :email,          null: false
      t.string  :document
      t.string  :phone
      t.string  :external_id
      t.string  :status,         null: false, default: "active"
      t.integer :health_score,   null: false, default: 100
      t.jsonb   :gateway_data,   null: false, default: {}
      t.jsonb   :metadata,       null: false, default: {}
      t.text    :notes
      t.timestamps
    end
    add_index :customers, [:account_id, :email], unique: true
    add_index :customers, [:account_id, :external_id],
              unique: true,
              where: "external_id IS NOT NULL"
  end
end
