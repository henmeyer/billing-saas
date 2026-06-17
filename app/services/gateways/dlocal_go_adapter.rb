# frozen_string_literal: true

module Gateways
  class DlocalGoAdapter < Base
    # dLocal Go — todas as cobranças via checkout (redirect).
    #
    # Fluxo:
    # 1. create_subscription → cria payment (checkout) → cliente paga via Pix/cartão/boleto
    # 2. Webhook confirma pagamento → assinatura ativada
    # 3. Renovação → RenewDlocalGoJob cria novo payment → cliente recebe link e paga
    # 4. Webhook confirma → período renovado
    #
    # Não usa recurring/tokenização — cada cobrança gera um checkout novo.
    # Isso permite que o cliente escolha o método de pagamento a cada vez.

    def initialize
      gateway = ActsAsTenant.current_tenant
                            .payment_gateways
                            .find_by!(provider: "dlocal_go")
      @api_key     = gateway.api_key
      @secret_key  = gateway.secret_key
      @environment = gateway.gateway_data.fetch("sandbox", true) ? "sandbox" : "production"
      @country     = gateway.gateway_data.fetch("default_country", "BR")

      @client = build_client(@api_key, @secret_key, @environment)
    end

    # dLocal Go não tem customer API — salva referência local
    def create_customer(customer)
      ref = customer.external_id || customer.id.to_s
      customer.gateway_data["dlocal_go"] ||= {}
      customer.gateway_data["dlocal_go"]["reference"] = ref
      customer.save!
      { "id" => ref }
    end

    # Cria um payment (checkout redirect) para o primeiro pagamento da assinatura
    def create_subscription(customer, plan, amount_cents: nil, currency: "BRL",
                            country: nil, **_opts)
      amount   = (amount_cents || plan.price_cents) / 100.0
      order_id = "sub_#{customer.id}_#{Time.current.to_i}"

      response = @client.create_payment({
                                          amount:           amount,
                                          currency:         currency,
                                          # country:          country || @country,
                                          order_id:         order_id,
                                          description:      "#{plan.name} — #{customer.name}",
                                          notification_url: notification_url,
                                          external_id:      order_id
                                        })

      Rails.logger.info("\n\n\n#{notification_url}\n\n\n")

      OpenStruct.new(
        id:           order_id,
        checkout_id:  response.id,
        redirect_url: response.redirect_url,
        status:       response.status
      )
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.respond_to?(:error_code) ? e.error_code : nil)
    end

    # Cancelar — não existe subscription no dLocal Go.
    def cancel_subscription(_gateway_subscription_id)
      {}
    end

    # Atualizar — noop, próxima cobrança usará o novo valor.
    def update_subscription(_gateway_subscription_id, _new_plan, amount_cents: nil)
      {}
    end

    # Cobrança (checkout redirect) — usada para renovações e compras avulsas.
    # Retorna redirect_url para o cliente pagar.
    def create_charge(customer, amount_cents, opts = {})
      currency = opts[:currency] || "BRL"
      country  = opts[:country]  || @country
      prefix   = opts[:prefix]   || "charge"
      order_id = "#{prefix}_#{customer.id}_#{Time.current.to_i}"

      response = @client.create_payment({
                                          amount:           amount_cents / 100.0,
                                          currency:         currency,
                                          country:          country,
                                          order_id:         order_id,
                                          description:      opts[:description] || "Cobrança",
                                          notification_url: notification_url,
                                          external_id:      order_id
                                        })

      {
        "id"           => response.id,
        "order_id"     => order_id,
        "status"       => response.status,
        "redirect_url" => response.redirect_url
      }
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.respond_to?(:error_code) ? e.error_code : nil)
    end

    # Estorno
    def create_refund(payment_id, amount_cents: nil)
      params = { payment_id: payment_id }
      params[:amount] = amount_cents / 100.0 if amount_cents

      response = @client.create_refund(params)
      { "id" => response.id, "status" => response.status }
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.respond_to?(:error_code) ? e.error_code : nil)
    end

    # Consultar pagamento
    def get_payment(payment_id)
      response = @client.get_payment(payment_id: payment_id)
      { "id" => response.id, "status" => response.status, "amount" => response.amount }
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.respond_to?(:error_code) ? e.error_code : nil)
    end

    def test_connection
      @client.get_all_recurring_payments
      { success: true, message: "Conexão com dLocal Go OK" }
    rescue DlocalGo::Error => e
      { success: false, message: "Erro dLocal Go: #{e.message}" }
    rescue StandardError => e
      { success: false, message: "Erro: #{e.message}" }
    end

    private

    # Cria instância do Client com credenciais injetadas diretamente,
    # sem depender da config global. Thread-safe para multi-tenant.
    def build_client(api_key, api_secret, environment)
      client = nil
      old_key    = DlocalGo.api_key
      old_secret = DlocalGo.api_secret
      old_env    = DlocalGo.environment

      begin
        DlocalGo.api_key     = api_key
        DlocalGo.api_secret  = api_secret
        DlocalGo.environment = environment
        client = DlocalGo::Client.new
      ensure
        DlocalGo.api_key     = old_key
        DlocalGo.api_secret  = old_secret
        DlocalGo.environment = old_env
      end

      # Garante que a instância usa ESTAS credenciais
      client.instance_variable_set(:@api_key, api_key)
      client.instance_variable_set(:@api_secret, api_secret)
      client.instance_variable_set(:@base_url,
                                   environment == "production" ? DlocalGo::Constants::PRODUCTION_URL : DlocalGo::Constants::SANDBOX_URL)
      client
    end

    def notification_url
      host = ENV.fetch("APP_HOST") { Rails.application.routes.default_url_options[:host] || "http://localhost:3001" }
      "#{host}/webhooks/dlocal_go"
    end
  end
end
