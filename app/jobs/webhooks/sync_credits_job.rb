class Webhooks::SyncCreditsJob < ApplicationJob
  queue_as :webhooks

  def perform(payload)
    customer = Customer.find_by(external_id: payload["customer_id"])
    return unless customer

    ActsAsTenant.current_tenant = customer.account

    period = customer.current_period
    return unless period

    credit_type = CreditType.find_by!(key: payload["credit_type"])

    used  = payload["used"].to_i
    limit = payload["limit"]&.to_i || credit_limit_from_plan(customer, credit_type)

    snapshot = period.credit_snapshots.find_or_initialize_by(
      credit_type: credit_type
    )

    snapshot.update!(
      used:      used,
      limit:     limit,
      synced_at: Time.current
    )

    Credits::CheckThresholdsService.call(customer, snapshot)
  end

  private

  def credit_limit_from_plan(customer, credit_type)
    plan_credit = customer.active_subscription
                          &.plan
                          &.plan_credits
                          &.find_by(credit_type: credit_type)
    plan_credit&.quantity || 0
  end
end
