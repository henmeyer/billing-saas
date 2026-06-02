class CreateIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :integrations do |t|
      t.references :account,  null: false, foreign_key: true
      t.string  :name,        null: false
      t.string  :url,         null: false
      t.string  :secret,      null: false
      t.string  :events,      array: true, default: []
      t.boolean :active,      null: false, default: true
      t.integer :retry_count, null: false, default: 5
      t.datetime :last_error_at
      t.timestamps
    end
  end
end
