class Credits::CheckThresholdsService
  THRESHOLDS = [80, 95, 100].freeze

  def self.call(customer, snapshot)
    new(customer, snapshot).call
  end

  def initialize(customer, snapshot)
    @customer = customer
    @snapshot = snapshot
  end

  def call
    THRESHOLDS.each do |threshold|
      next unless @snapshot.usage_percent >= threshold
      next if alert_already_sent?(threshold)

      create_alert(threshold)
      dispatch_webhook(threshold)
    end
  end

  private

  def alert_already_sent?(threshold)
    period_start = @customer.active_subscription&.current_period_start
    return false unless period_start

    @customer.credit_alerts.exists?(
      credit_type:  @snapshot.credit_type,
      threshold:    threshold,
      period_start: period_start..
    )
  end

  def create_alert(threshold)
    @customer.credit_alerts.create!(
      credit_type:  @snapshot.credit_type,
      threshold:    threshold,
      period_start: @customer.active_subscription.current_period_start
    )
  end

  def dispatch_webhook(threshold)
    event = threshold == 100 ? "credits.depleted" : "credits.threshold_reached"

    WebhookDispatchJob.perform_later(
      @customer,
      event,
      {
        credit_type:   @snapshot.credit_type.key,
        used:          @snapshot.used,
        limit:         @snapshot.limit,
        usage_percent: @snapshot.usage_percent,
        threshold:     threshold
      }
    )
  end
end
