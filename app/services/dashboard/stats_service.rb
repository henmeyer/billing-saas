class Dashboard::StatsService
  def self.call(account)
    new(account).call
  end

  def initialize(account)
    @account = account
  end

  def call
    ActsAsTenant.with_tenant(@account) do
      {
        mrr:                calculate_mrr,
        arr:                calculate_mrr * 12,
        active_customers:   Customer.active.count,
        churned_this_month: churned_this_month,
        past_due:           past_due_count,
        at_risk:            Customer.at_risk.count,
        revenue_this_month: revenue_this_month,
        mrr_by_plan:        mrr_by_plan,
        recent_charges:     recent_charges,
        credits_depleted:   credits_depleted_count
      }
    end
  end

  private

  def calculate_mrr
    Subscription.active
                .includes(:currency, plan: :plan_prices)
                .sum(&:price_in_currency) / 100.0
  end

  def churned_this_month
    Subscription.where(
      status:       "cancelled",
      cancelled_at: Time.current.beginning_of_month..
    ).count
  end

  def past_due_count
    Subscription.where(status: "past_due").count
  end

  def revenue_this_month
    Charge.paid
          .where(paid_at: Time.current.beginning_of_month..)
          .sum(:amount_cents) / 100.0
  end

  def mrr_by_plan
    Subscription.active
                .includes(:currency, plan: :plan_prices)
                .group_by { |s| s.plan.name }
                .transform_values { |subs| subs.sum(&:price_in_currency) / 100.0 }
  end

  def recent_charges
    Charge.includes(:customer)
          .order(created_at: :desc)
          .limit(5)
          .map do |c|
            {
              customer_name: c.customer.name,
              amount:        c.amount_cents / 100.0,
              status:        c.status,
              created_at:    c.created_at.iso8601
            }
          end
  end

  def credits_depleted_count
    CreditAlert.where(
      threshold:    100,
      period_start: Time.current.beginning_of_month..
    ).count
  end
end
