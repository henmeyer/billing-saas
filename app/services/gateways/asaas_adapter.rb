module Gateways
  class AsaasAdapter < Base
    SANDBOX_URL    = "https://api-sandbox.asaas.com/v3".freeze
    PRODUCTION_URL = "https://api.asaas.com/v3".freeze

    def initialize
      gateway = ActsAsTenant.current_tenant
                            .payment_gateways
                            .find_by!(provider: "asaas")
      @api_key  = gateway.api_key
      @base_url = gateway.gateway_data.fetch("sandbox", true) ? SANDBOX_URL : PRODUCTION_URL
    end

    # ─── Customer ───────────────────────────────────
    # Asaas TEM customer API — criar/buscar customer

    def create_customer(customer)
      # Busca se já existe no Asaas
      existing_id = customer.gateway_data.dig("asaas", "customer_id")
      if existing_id
        begin
          return get("/customers/#{existing_id}")
        rescue GatewayError
          # Não encontrou, cria novo
        end
      end

      response = post("/customers", {
                        name:              customer.name,
                        email:             customer.email,
                        cpfCnpj:           customer.document,
                        phone:             customer.phone,
                        externalReference: customer.external_id || customer.id.to_s
                      })

      customer.gateway_data["asaas"] ||= {}
      customer.gateway_data["asaas"]["customer_id"] = response["id"]
      customer.save!

      response
    end

    # ─── Subscription (LEGACY — só para gateway_managed) ───
    # Usado apenas para subscriptions existentes que ainda são
    # gerenciadas pelo Asaas. Novas subscriptions usam create_charge.

    def create_subscription_legacy(customer, plan, amount_cents: nil,
                                   billing_type: "UNDEFINED", **_opts)
      asaas_customer_id = ensure_customer(customer)
      value = (amount_cents || plan.price_for(Currency.find_by(default: true))) / 100.0

      post("/subscriptions", {
             customer:          asaas_customer_id,
             billingType:       billing_type,
             value:             value,
             cycle:             asaas_cycle(plan.billing_cycle),
             nextDueDate:       Date.tomorrow.strftime("%Y-%m-%d"),
             description:       plan.name,
             externalReference: "plan_#{plan.id}_customer_#{customer.id}"
           })
    end

    # ─── Subscription (NOVA — billing-managed) ─────────
    # Para novas subscriptions: billing controla o ciclo,
    # Asaas só processa o pagamento.
    # Retorna dados compatíveis com a interface comum.

    def create_subscription(customer, plan, amount_cents: nil, currency: "BRL",
                            billing_type: "UNDEFINED", **_opts)
      ensure_customer(customer)

      charge_amount = amount_cents || plan.price_for(Currency.find_by(code: currency) || Currency.find_by(default: true))

      result = create_charge(
        customer,
        charge_amount,
        billing_type: billing_type,
        description:  "#{plan.name} — Primeira cobrança",
        currency:     currency
      )

      order_id = "sub_#{customer.id}_#{Time.current.to_i}"

      OpenStruct.new(
        id:           order_id,
        payment_id:   result["id"],
        redirect_url: nil, # Asaas não precisa de redirect para Pix/Boleto
        status:       result["status"],
        pix:          extract_pix(result),
        boleto:       extract_boleto(result),
        invoice_url:  result["invoiceUrl"],
        charge_id:    result["id"]
      )
    end

    def cancel_subscription(gateway_sub_id)
      return {} if gateway_sub_id.blank?

      # billing-managed subscriptions usam formato "sub_CUSTOMERID_TIMESTAMP"
      return {} if billing_managed_sub_id?(gateway_sub_id)

      delete("/subscriptions/#{gateway_sub_id}")
    rescue GatewayError => e
      # Ignora se já cancelada
      Rails.logger.warn("[Asaas] Cancel failed: #{e.message}")
      {}
    end

    def update_subscription(gateway_sub_id, new_plan, amount_cents: nil)
      # Para billing-managed: noop (próximo payment usa novo valor)
      return {} if gateway_sub_id.blank? || billing_managed_sub_id?(gateway_sub_id)

      # Para gateway-managed: atualiza no Asaas
      value = (amount_cents || new_plan.price_for(Currency.find_by(default: true))) / 100.0
      put("/subscriptions/#{gateway_sub_id}", {
            value: value,
            cycle: asaas_cycle(new_plan.billing_cycle)
          })
    rescue GatewayError => e
      Rails.logger.warn("[Asaas] Update subscription failed: #{e.message}")
      {}
    end

    # ─── Charge (pagamento avulso) ──────────────────
    # Usado para: renovações billing-managed, compras avulsas, trial conversion

    def create_charge(customer, amount_cents, opts = {})
      asaas_customer_id = ensure_customer(customer)
      billing_type      = opts[:billing_type] || "UNDEFINED"
      due_date          = opts[:due_date] || 3.days.from_now.strftime("%Y-%m-%d")

      response = post("/payments", {
                        customer:          asaas_customer_id,
                        billingType:       billing_type,
                        value:             amount_cents / 100.0,
                        dueDate:           due_date,
                        description:       opts[:description] || "Cobrança",
                        externalReference: "charge_#{customer.id}_#{Time.current.to_i}"
                      })

      # Se for Pix, busca o QR code
      if billing_type == "PIX" && response["id"]
        pix_data = get_pix_data(response["id"])
        response.merge!(pix_data) if pix_data
      end

      response
    end

    # ─── Pix QR Code ────────────────────────────────
    # Asaas gera o Pix QR code separadamente

    def get_pix_data(payment_id)
      get("/payments/#{payment_id}/pixQrCode")
    rescue GatewayError => e
      Rails.logger.warn("[Asaas] Pix QR failed: #{e.message}")
      nil
    end

    # ─── Boleto ─────────────────────────────────────

    def get_boleto_data(payment_id)
      get("/payments/#{payment_id}/identificationField")
    rescue GatewayError => e
      Rails.logger.warn("[Asaas] Boleto data failed: #{e.message}")
      nil
    end

    # ─── Refund ─────────────────────────────────────

    def create_refund(payment_id, amount_cents: nil)
      body = {}
      body[:value] = amount_cents / 100.0 if amount_cents
      post("/payments/#{payment_id}/refund", body)
    end

    # ─── Consulta ───────────────────────────────────

    def get_payment(payment_id)
      get("/payments/#{payment_id}")
    end

    # ─── Test Connection ────────────────────────────

    def test_connection
      response = HTTParty.get(
        "#{@base_url}/finance/balance",
        headers: headers
      )
      if response.success?
        { success: true, message: "Conexão com Asaas OK" }
      else
        { success: false, message: "Falha na autenticação: #{response.parsed_response}" }
      end
    rescue StandardError => e
      { success: false, message: "Erro: #{e.message}" }
    end

    private

    def ensure_customer(customer)
      customer.gateway_data.dig("asaas", "customer_id") ||
        create_customer(customer)["id"]
    end

    # billing-managed sub IDs seguem o padrão: sub_CUSTOMERID_TIMESTAMP
    # Ex: "sub_42_1700000000"
    # IDs nativos do Asaas são alfanuméricos sem esse padrão
    def billing_managed_sub_id?(sub_id)
      sub_id.present? && sub_id.match?(/\Asub_\d+_\d+\z/)
    end

    def extract_pix(result)
      return nil unless result["encodedImage"] || result["payload"] || result["pixQrCodeBase64"]

      {
        qr_code:    result["encodedImage"] || result["pixQrCodeBase64"],
        copy_paste: result["payload"] || result["pixCopiaECola"],
        expiration: result["expirationDate"]
      }
    end

    def extract_boleto(result)
      return nil unless result["bankSlipUrl"] || result["identificationField"]

      {
        url:      result["bankSlipUrl"],
        barcode:  result["identificationField"],
        due_date: result["dueDate"]
      }
    end

    def asaas_cycle(billing_cycle)
      case billing_cycle
      when "yearly"    then "YEARLY"
      when "quarterly" then "QUARTERLY"
      else "MONTHLY"
      end
    end

    def post(path, body)
      response = HTTParty.post(
        "#{@base_url}#{path}",
        headers: headers,
        body:    body.to_json
      )
      handle_response(response)
    end

    def get(path)
      response = HTTParty.get(
        "#{@base_url}#{path}",
        headers: headers
      )
      handle_response(response)
    end

    def put(path, body)
      response = HTTParty.put(
        "#{@base_url}#{path}",
        headers: headers,
        body:    body.to_json
      )
      handle_response(response)
    end

    def delete(path)
      response = HTTParty.delete(
        "#{@base_url}#{path}",
        headers: headers
      )
      handle_response(response)
    end

    def headers
      {
        "access_token" => @api_key,
        "Content-Type" => "application/json"
      }
    end

    def handle_response(response)
      parsed = response.parsed_response

      unless response.success?
        msg = if parsed.is_a?(Hash)
                parsed["errors"]&.map { |e| e["description"] }&.join(", ") ||
                  parsed["message"] || response.body
              else
                response.body
              end
        raise GatewayError.new(msg, code: response.code)
      end

      parsed
    end
  end
end
