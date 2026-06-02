class CreatePlans < ActiveRecord::Migration[7.1]
  def change
    create_table :plans do |t|
      t.references :account,    null: false, foreign_key: true
      t.string  :name,          null: false
      t.text    :description
      t.integer :price_cents,   null: false, default: 0
      t.string  :currency,      null: false, default: "BRL"
      t.string  :billing_cycle, null: false, default: "monthly"
      t.integer :trial_days,    null: false, default: 0
      t.boolean :active,        null: false, default: true
      t.datetime :archived_at
      t.jsonb   :gateway_data,  null: false, default: {}
      t.jsonb   :metadata,      null: false, default: {}
      t.timestamps
    end
  end
end
