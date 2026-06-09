class Webhooks::TestService
  TIMEOUT = 10.seconds

  TEST_PAYLOADS = {
    "subscription.activated"    => { plan: { id: 0, name: "Plano de Teste" } },
    "subscription.cancelled"    => {},
    "subscription.past_due"     => {},
    "subscription.renewed"      => { period_end: -> { 1.month.from_now.iso8601 } },
    "subscription.trial_ending" => {
      trial_ends_at:  -> { 3.days.from_now.iso8601 },
      days_remaining: 3
    },
    "plan.changed" => {
      previous_plan: { id: 0, name: "Plano Anterior" },
      new_plan:      { id: 0, name: "Plano Novo" }
    },
    "payment.received" => {
      amount_cents: 19700,
      gateway:      "asaas",
      charge_id:    -> { "test_pay_#{SecureRandom.hex(8)}" }
    },
    "payment.failed" => {
      amount_cents: 19700,
      gateway:      "asaas",
      attempt:      1
    },
    "credits.threshold_reached" => {
      credit_type:   "coins",
      used:          800,
      limit:         1000,
      usage_percent: 80.0,
      threshold:     80
    },
    "credits.depleted" => {
      credit_type:   "coins",
      used:          1000,
      limit:         1000,
      usage_percent: 100.0
    },
    "credits.recharged" => {
      credit_type:  "coins",
      added:        1000,
      new_balance:  2000
    },
    "license.updated" => {
      license_type:      "user_licenses",
      previous_quantity: 10,
      new_quantity:      20
    }
  }.freeze

  Result = Struct.new(
    :success?,
    :status_code,
    :response_body,
    :duration_ms,
    :error,
    keyword_init: true
  )

  def self.call(integration:, event:)
    new(integration:, event:).call
  end

  def initialize(integration:, event:)
    @integration = integration
    @event       = event
  end

  def call
    payload  = build_payload
    body     = payload.to_json
    sig      = sign(body)
    started  = Time.current

    response = HTTParty.post(
      @integration.url,
      body:    body,
      headers: {
        "Content-Type"        => "application/json",
        "X-Billing-Signature" => "sha256=#{sig}",
        "X-Webhook-Event"     => @event,
        "X-Webhook-Test"      => "true",
        "X-Webhook-Id"        => SecureRandom.uuid
      },
      timeout: TIMEOUT
    )

    duration = ((Time.current - started) * 1000).round

    log_test(payload, response.code, response.body.truncate(500), duration)

    Result.new(
      success?:      response.success?,
      status_code:   response.code,
      response_body: response.body.truncate(200),
      duration_ms:   duration,
      error:         nil
    )

  rescue Net::OpenTimeout, Net::ReadTimeout
    duration = (TIMEOUT * 1000).round
    log_test(payload, nil, "Timeout após #{TIMEOUT}s", duration)

    Result.new(
      success?:      false,
      status_code:   nil,
      response_body: nil,
      duration_ms:   duration,
      error:         "Timeout — servidor não respondeu em #{TIMEOUT}s"
    )

  rescue => e
    log_test(payload, nil, e.message, 0)

    Result.new(
      success?:      false,
      status_code:   nil,
      response_body: nil,
      duration_ms:   0,
      error:         e.message
    )
  end

  private

  def build_payload
    {
      event:      @event,
      timestamp:  Time.current.iso8601,
      account_id: @integration.account.id.to_s,
      test:       true,
      customer: {
        id:          "0",
        external_id: "test_customer",
        name:        "Cliente de Teste",
        email:       "teste@exemplo.com"
      },
      features: {
        "ai_enabled"     => true,
        "export_reports" => false
      },
      data: resolve_payload(TEST_PAYLOADS[@event] || {})
    }
  end

  def resolve_payload(template)
    template.transform_values { |v| v.respond_to?(:call) ? v.call : v }
  end

  def sign(body)
    OpenSSL::HMAC.hexdigest("SHA256", @integration.secret, body)
  end

  def log_test(payload, status_code, response_body, duration_ms)
    WebhookLog.create!(
      integration:   @integration,
      customer:      @integration.account.customers.first,
      event:         @event,
      payload:       payload,
      status:        status_code&.between?(200, 299) ? "delivered" : "failed",
      attempts:      1,
      is_test:       true,
      response_code: status_code,
      response_body: response_body,
      duration_ms:   duration_ms
    )
  rescue => e
    Rails.logger.warn("[WebhookTest] Erro ao salvar log: #{e.message}")
  end
end
