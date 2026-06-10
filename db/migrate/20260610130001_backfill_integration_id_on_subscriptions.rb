class BackfillIntegrationIdOnSubscriptions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    say "Backfilling integration_id on subscriptions..."

    ActsAsTenant.without_tenant do
      subscriptions_without_integration = Subscription.where(integration_id: nil)
      total = subscriptions_without_integration.count
      updated = 0
      skipped = 0
      conflicts = 0

      subscriptions_without_integration.find_each do |subscription|
        integration_id = resolve_integration_id(subscription)

        if integration_id.nil?
          say "WARNING: Could not resolve integration for subscription ##{subscription.id} " \
              "(customer_id: #{subscription.customer_id}, plan_id: #{subscription.plan_id})", true
          skipped += 1
          next
        end

        begin
          subscription.update_columns(integration_id: integration_id)
          updated += 1
        rescue ActiveRecord::RecordNotUnique
          say "CONFLICT: Subscription ##{subscription.id} would violate unique constraint " \
              "(customer_id: #{subscription.customer_id}, integration_id: #{integration_id}). " \
              "Another active subscription already exists for this pair. Skipping — resolve manually.", true
          conflicts += 1
        end
      end

      say "Backfill complete: #{updated}/#{total} updated, #{skipped} unresolved, #{conflicts} conflicts"

      if conflicts > 0
        say "WARNING: #{conflicts} subscriptions have duplicate active customer+integration pairs. " \
            "These must be resolved manually before setting integration_id NOT NULL.", true
      end
    end
  end

  def down
    # Data migration — no-op on rollback (column remains nullable from previous migration)
  end

  private

  def resolve_integration_id(subscription)
    plan_integration_ids = PlanIntegration
      .where(plan_id: subscription.plan_id)
      .pluck(:integration_id)

    return nil if plan_integration_ids.empty?

    # If only one integration linked to the plan, use it
    return plan_integration_ids.first if plan_integration_ids.size == 1

    # If multiple, prefer the one that has a customer_identity for this customer
    matching_integration_id = CustomerIdentity
      .where(customer_id: subscription.customer_id, integration_id: plan_integration_ids)
      .pick(:integration_id)

    # Return the matching one, or fallback to the first
    matching_integration_id || plan_integration_ids.first
  end
end
