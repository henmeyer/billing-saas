class AddUuidToWebhookLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :webhook_logs, :uuid, :string, null: false, default: -> { "gen_random_uuid()" }
    add_index  :webhook_logs, :uuid, unique: true
  end
end
