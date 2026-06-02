class CreatePaymentGateways < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_gateways do |t|
      t.references :account,    null: false, foreign_key: true
      t.string  :provider,      null: false
      t.string  :api_key_enc,   null: false
      t.string  :webhook_secret
      t.boolean :active,        null: false, default: true
      t.boolean :default,       null: false, default: false
      t.timestamps
    end
    add_index :payment_gateways, [:account_id, :provider], unique: true
  end
end
