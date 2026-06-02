class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|
      t.string  :name,     null: false
      t.string  :slug,     null: false
      t.string  :status,   null: false, default: "active"
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
    end
    add_index :accounts, :slug, unique: true
  end
end
