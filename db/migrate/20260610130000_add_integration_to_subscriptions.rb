class AddIntegrationToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_reference :subscriptions, :integration, foreign_key: true, null: true

    add_index :subscriptions, [:customer_id, :integration_id],
              unique: true,
              where: "status IN ('active', 'trialing', 'past_due')",
              name: "idx_unique_active_subscription_per_customer_integration"
  end
end
