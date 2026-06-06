class WebhookDispatchJob < ApplicationJob
  queue_as :webhooks

  RETRY_DELAYS = [1.minute, 5.minutes, 30.minutes, 2.hours, 8.hours].freeze
  TIMEOUT      = 10

  def perform(customer, event_name, data, attempt: 1)
    ActsAsTenant.current_tenant = customer.account

    integrations = customer.account
                           .integrations
                           .active
                           .select { |i| i.events_for(event_name) }

    integrations.each do |integration|
      dispatch(integration, customer, event_name, data, attempt)
    end
  end

  private

  def dispatch(integration, customer, event_name, data, attempt)
    payload = build_payload(event_name, customer, data)
    body    = payload.to_json
    sig     = sign_payload(integration.secret, body)

    log = WebhookLog.create!(
      integration: integration,
      customer:    customer,
      event:       event_name,
      payload:     payload,
      status:      "pending",
      attempts:    attempt
    )

    begin
      response = HTTParty.post(
        integration.url,
        body:    body,
        headers: {
          "Content-Type"        => "application/json",
          "X-Billing-Signature" => "sha256=#{sig}",
          "X-Webhook-Id"        => log.id.to_s,
          "X-Webhook-Event"     => event_name,
          "X-Webhook-Attempt"   => attempt.to_s
        },
        timeout: TIMEOUT
      )

      if response.success?
        log.update!(status: "delivered")
      else
        handle_failure(log, integration, customer, event_name, data, attempt,
                       "HTTP #{response.code}: #{response.body.truncate(200)}")
      end
    rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout => e
      handle_failure(log, integration, customer, event_name, data, attempt, e.message)
    end
  end

  def handle_failure(log, integration, customer, event_name, data, attempt, error_msg)
    next_delay = RETRY_DELAYS[attempt - 1]

    if next_delay
      retry_at = next_delay.from_now
      log.update!(status: "pending", next_retry_at: retry_at)
      integration.update!(last_error_at: Time.current)

      WebhookDispatchJob
        .set(wait_until: retry_at)
        .perform_later(customer, event_name, data, attempt: attempt + 1)
    else
      log.update!(status: "failed")
      Rails.logger.error(
        "Webhook falhou permanentemente: integration=#{integration.id} " \
        "event=#{event_name} customer=#{customer.id} error=#{error_msg}"
      )
    end
  end

  def build_payload(event_name, customer, data)
    subscription = customer.active_subscription

    features = {}
    if subscription
      subscription.plan.plan_features.includes(:feature_type).each do |pf|
        features[pf.feature_type.key] = pf.enabled
      end
    end

    {
      event:      event_name,
      timestamp:  Time.current.iso8601,
      account_id: customer.account.id.to_s,
      customer:   {
        id:          customer.id.to_s,
        external_id: customer.external_id,
        name:        customer.name,
        email:       customer.email
      },
      features:   features,
      data:       data
    }
  end

  def sign_payload(secret, body)
    OpenSSL::HMAC.hexdigest("SHA256", secret, body)
  end
end
