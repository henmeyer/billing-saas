class CreateWebhookLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_logs do |t|
      t.references :integration, null: false, foreign_key: true
      t.references :customer,    null: false, foreign_key: true
      t.string  :event,          null: false
      t.jsonb   :payload,        null: false, default: {}
      t.string  :status,         null: false, default: "pending"
      t.integer :attempts,       null: false, default: 0
      t.datetime :next_retry_at
      t.timestamps
    end
    add_index :webhook_logs, [:integration_id, :status]
    add_index :webhook_logs, :next_retry_at
  end
end
