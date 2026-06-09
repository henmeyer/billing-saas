class AddMetadataToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :subscriptions, :metadata, :jsonb, null: false, default: {}
  end
end
