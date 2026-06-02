class CreateCharges < ActiveRecord::Migration[7.1]
  def change
    create_table :charges do |t|
      t.references :customer,     null: false, foreign_key: true
      t.references :subscription, null: false, foreign_key: true
      t.string  :gateway,         null: false
      t.string  :gateway_charge_id
      t.integer :amount_cents,    null: false
      t.string  :currency,        null: false, default: "BRL"
      t.string  :status,          null: false, default: "pending"
      t.date    :due_date
      t.datetime :paid_at
      t.timestamps
    end
    add_index :charges, [:gateway, :gateway_charge_id],
              unique: true,
              where: "gateway_charge_id IS NOT NULL"
  end
end
