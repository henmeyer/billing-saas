class MakeIntegrationIdNotNullOnSubscriptions < ActiveRecord::Migration[7.1]
  def up
    remaining = ActsAsTenant.without_tenant { Subscription.where(integration_id: nil).count }

    if remaining > 0
      raise "Cannot set NOT NULL: #{remaining} subscriptions still have NULL integration_id. " \
            "Please resolve these manually before running this migration."
    end

    change_column_null :subscriptions, :integration_id, false
  end

  def down
    change_column_null :subscriptions, :integration_id, true
  end
end
