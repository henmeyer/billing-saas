class CreateApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :api_keys do |t|
      t.references :account,   null: false, foreign_key: true
      t.string  :name,         null: false
      t.string  :token_digest, null: false
      t.string  :last_four,    null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.boolean :active,       null: false, default: true
      t.timestamps
    end
    add_index :api_keys, :token_digest, unique: true
  end
end
