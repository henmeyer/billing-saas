class Subscriptions::CheckTrialsJob < ApplicationJob
  queue_as :billing

  # Rodar diariamente via cron
  def perform
    notify_expiring_soon
    notify_expired
  end

  private

  # 3 dias antes do trial expirar
  def notify_expiring_soon
    Subscription.trial_expiring_in(3.days)
                .where("trial_ends_at > ?", Time.current)
                .includes(:customer, :plan)
                .find_each do |sub|
      next if sub.metadata["trial_ending_notified"]

      ActsAsTenant.current_tenant = sub.customer.account

      WebhookDispatchJob.perform_later(
        sub.customer,
        "subscription.trial_ending",
        {
          trial_ends_at:  sub.trial_ends_at.iso8601,
          days_remaining: sub.trial_days_remaining,
          plan:           { id: sub.plan.id, name: sub.plan.name }
        }
      )

      sub.update!(metadata: sub.metadata.merge("trial_ending_notified" => true))
    end
  end

  # Trial expirou — cancela e notifica
  def notify_expired
    Subscription.trial_expired
                .includes(:customer, :plan)
                .find_each do |sub|
      ActsAsTenant.current_tenant = sub.customer.account

      WebhookDispatchJob.perform_later(
        sub.customer,
        "subscription.cancelled",
        { reason: "trial_expired", plan: { id: sub.plan.id, name: sub.plan.name } }
      )

      sub.update!(status: "cancelled", cancelled_at: Time.current)
    end
  end
end
