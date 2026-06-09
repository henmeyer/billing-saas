class AddTestToWebhookLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :webhook_logs, :is_test,       :boolean, null: false, default: false
    add_column :webhook_logs, :response_code, :integer
    add_column :webhook_logs, :response_body, :text
    add_column :webhook_logs, :duration_ms,   :integer
  end
end
