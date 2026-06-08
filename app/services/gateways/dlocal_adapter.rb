module Gateways
  class DlocalAdapter < Base
    SANDBOX_URL    = "https://sandbox.dlocal.com".freeze
    PRODUCTION_URL = "https://api.dlocal.com".freeze

    def initialize
      gateway     = ActsAsTenant.current_tenant
                                .payment_gateways
                                .find_by!(provider: "dlocal")
      @login      = gateway.api_key
      @secret_key = gateway.secret_key
      @base_url = gateway.gateway_data.fetch("sandbox", true) ? SANDBOX_URL : PRODUCTION_URL
    end

    # dLocal não tem concept de "customer" separado.
    # Salva referência externa no gateway_data para uso nos payments.
    def create_customer(customer)
      customer.gateway_data["dlocal"] ||= {}
      customer.gateway_data["dlocal"]["external_id"] = customer.external_id || customer.id.to_s
      customer.save!
      { "id" => customer.external_id || customer.id.to_s }
    end

    # dLocal não tem subscriptions — cria um payment individual por ciclo.
    def create_subscription(customer, plan, amount_cents: nil, currency: "BRL", country: "BR", payment_method: "CARD")
      amount   = (amount_cents || plan.price_cents) / 100.0
      order_id = "sub_#{customer.id}_#{Time.current.to_i}"

      response = post("/payments", {
                        amount:              amount,
                        currency:            currency,
                        country:             country,
                        payment_method_id:   payment_method,
                        payment_method_flow: "DIRECT",
                        payer:               {
                          name:           customer.name,
                          email:          customer.email,
                          document:       customer.document,
                          user_reference: customer.external_id || customer.id.to_s
                        },
                        order_id:            order_id,
                        description:         plan.name,
                        notification_url:    "#{Rails.application.routes.url_helpers.root_url}webhooks/dlocal",
                        external_reference:  "plan_#{plan.id}_customer_#{customer.id}"
                      })

      customer.gateway_data["dlocal"] ||= {}
      customer.gateway_data["dlocal"]["last_payment_id"] = response["id"]
      customer.save!

      response
    end

    # dLocal não tem subscription — cancela o payment se ainda pendente.
    def cancel_subscription(gateway_subscription_id)
      post("/payments/#{gateway_subscription_id}/cancel", {})
    rescue GatewayError
      {}
    end

    # dLocal não permite atualizar payments — próxima cobrança usa o novo valor.
    def update_subscription(_gateway_subscription_id, _new_plan, amount_cents: nil)
      {}
    end

    def create_charge(customer, amount_cents, opts = {})
      amount   = amount_cents / 100.0
      currency = opts[:currency]        || "BRL"
      country  = opts[:country]         || "BR"
      method   = opts[:payment_method]  || "BANK_TRANSFER"

      post("/payments", {
             amount:              amount,
             currency:            currency,
             country:             country,
             payment_method_id:   method,
             payment_method_flow: "REDIRECT",
             payer:               {
               name:           customer.name,
               email:          customer.email,
               document:       customer.document,
               user_reference: customer.external_id || customer.id.to_s
             },
             order_id:            "charge_#{customer.id}_#{Time.current.to_i}",
             description:         opts[:description] || "Cobrança",
             notification_url:    "#{Rails.application.routes.url_helpers.root_url}webhooks/dlocal"
           })
    end

    private

    # Autenticação dLocal: HMAC-SHA256 por requisição.
    # Signature = HMAC-SHA256(login + date + requestBody, secret_key)
    def auth_headers(body_json)
      date      = Time.current.utc.iso8601
      signature = OpenSSL::HMAC.hexdigest("SHA256", @secret_key, "#{@login}#{date}#{body_json}")

      {
        "X-Date"        => date,
        "X-Login"       => @login,
        "X-Trans-Key"   => @secret_key,
        "Authorization" => "V2-HMAC-SHA256, Signature=#{signature}",
        "Content-Type"  => "application/json",
        "X-Version"     => "2.1"
      }
    end

    def post(path, body)
      body_json = body.to_json
      response  = HTTParty.post(
        "#{@base_url}#{path}",
        headers: auth_headers(body_json),
        body:    body_json
      )
      handle_response(response)
    end

    def get(path)
      response = HTTParty.get(
        "#{@base_url}#{path}",
        headers: auth_headers("")
      )
      handle_response(response)
    end

    def handle_response(response)
      parsed = response.parsed_response

      unless response.success?
        message = parsed&.dig("message") || parsed&.dig("error") || response.body
        code    = parsed&.dig("code")
        raise GatewayError.new(message, code: code)
      end

      parsed
    end
  end
end
