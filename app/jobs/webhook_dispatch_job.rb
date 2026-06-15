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
    payload = build_payload(integration, customer, event_name, data)
    body    = payload.to_json
    sig     = sign_payload(integration.secret, body)

    log = WebhookLog.create!(
      integration: integration,
      customer:    customer,
      event:       event_name,
      payload:     payload,
      uuid:        payload[:uuid],
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
          "X-Webhook-Id"        => payload[:uuid],
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

  def build_payload(integration, customer, event, data)
    subscription = customer.subscriptions
                           .where(integration_id: integration.id)
                           .where(status: %w[active pending past_due])
                           .order(created_at: :desc)
                           .first

    external_id = customer.external_id_for(integration) || customer.id.to_s

    {
      event:        event,
      uuid:         SecureRandom.uuid,
      timestamp:    Time.current.iso8601,
      account_id:   customer.account_id.to_s,
      customer: {
        id:          customer.id.to_s,
        external_id: external_id,
        name:        customer.name,
        email:       customer.email
      },
      subscription: subscription ? build_subscription_data(subscription) : nil,
      features:     subscription ? build_features(subscription) : {},
      credits:      subscription ? build_credits(subscription) : {},
      licenses:     subscription ? build_licenses(subscription) : {},
      data:         data
    }
  end

  def build_subscription_data(subscription)
    {
      id:                 subscription.id,
      plan_id:            subscription.plan_id,
      plan_name:          subscription.plan.name,
      status:             subscription.status,
      billing_cycle:      subscription.plan.billing_cycle,
      base_price_cents:   subscription.base_price_cents,
      currency_code:      subscription.currency_code,
      current_period_end: subscription.current_period_end&.iso8601,
      started_at:         subscription.started_at&.iso8601
    }
  end

  def build_features(subscription)
    subscription.plan
                .plan_features
                .includes(:feature_type)
                .each_with_object({}) do |pf, hash|
      hash[pf.feature_type.key] = pf.enabled
    end
  end

  def build_credits(subscription)
    period = subscription.current_period
    return {} unless period

    period.subscription_period_credits
          .includes(:credit_type)
          .each_with_object({}) do |spc, hash|
      snapshot = period.credit_snapshots.find_by(credit_type: spc.credit_type)
      hash[spc.credit_type.key] = {
        limit:          spc.quantity,
        base:           spc.base,
        extras:         spc.extras,
        extra_packages: spc.extra_packages,
        used:           snapshot&.used || 0,
        balance:        snapshot&.balance || spc.quantity,
        usage_percent:  snapshot&.usage_percent || 0.0
      }
    end
  end

  def build_licenses(subscription)
    period = subscription.current_period
    return {} unless period

    customer = subscription.customer
    period.subscription_period_licenses
          .includes(:license_type)
          .each_with_object({}) do |spl, hash|
      used = customer.metadata.dig("license_usage", spl.license_type.key).to_i
      hash[spl.license_type.key] = {
        allocated: spl.unlimited? ? nil : spl.quantity,
        used:      used,
        available: spl.unlimited? ? nil : [spl.quantity - used, 0].max,
        unlimited: spl.unlimited?
      }
    end
  end

  def sign_payload(secret, body)
    OpenSSL::HMAC.hexdigest("SHA256", secret, body)
  end
end
