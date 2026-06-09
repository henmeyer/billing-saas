module Gateways
  class DlocalGoAdapter < Base
    def initialize
      gateway = ActsAsTenant.current_tenant
                            .payment_gateways
                            .find_by!(provider: "dlocal_go")

      DlocalGo.setup do |c|
        c.api_key     = gateway.api_key
        c.api_secret  = gateway.secret_key
        c.environment = gateway.gateway_data.fetch("sandbox", true) ? "sandbox" : "production"
      end

      @client = DlocalGo::Client.new
    end

    def create_customer(customer)
      customer.gateway_data["dlocal_go"] ||= {}
      customer.gateway_data["dlocal_go"]["external_id"] = customer.external_id || customer.id.to_s
      customer.save!
      { "id" => customer.external_id || customer.id.to_s }
    end

    # dLocal Go usa checkout hospedado para subscriptions.
    # Retorna checkout_url que o cliente deve visitar para se inscrever.
    # Plan precisa ter gateway_data["dlocal_go"]["plan_token"] configurado.
    def create_subscription(customer, plan, amount_cents: nil, currency: "BRL", country: "BR", payment_method: nil)
      plan_token = plan.gateway_data.dig("dlocal_go", "plan_token")
      raise GatewayError, "Plano não configurado no dLocal Go (falta plan_token em gateway_data)" unless plan_token

      checkout_url = DlocalGo::Utilities.subscription_url(token: plan_token, email: customer.email)
      { "checkout_url" => checkout_url, "type" => "redirect" }
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.error_code)
    end

    # gateway_subscription_id = "dlocal_plan_id|dlocal_subscription_id"
    def cancel_subscription(gateway_subscription_id)
      plan_id, subscription_id = gateway_subscription_id.split("|")
      @client.cancel_subscription(plan_id: plan_id, subscription_id: subscription_id)
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.error_code)
    end

    # Cancela a assinatura atual e retorna checkout_url para o novo plano.
    def update_subscription(gateway_subscription_id, new_plan, amount_cents: nil)
      plan_id, subscription_id = gateway_subscription_id.split("|")
      @client.cancel_subscription(plan_id: plan_id, subscription_id: subscription_id)

      new_plan_token = new_plan.gateway_data.dig("dlocal_go", "plan_token")
      raise GatewayError, "Novo plano não configurado no dLocal Go (falta plan_token)" unless new_plan_token

      { "checkout_url" => DlocalGo::Utilities.subscription_url(token: new_plan_token), "type" => "redirect" }
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.error_code)
    end

    def create_charge(customer, amount_cents, opts = {})
      response = @client.create_payment(
        amount:            amount_cents / 100.0,
        currency:          opts[:currency]       || "BRL",
        country:           opts[:country]        || "BR",
        payment_method_id: opts[:payment_method] || "CARD",
        payer:             build_payer(customer, opts[:country] || "BR"),
        order_id:          "charge_#{customer.id}_#{Time.current.to_i}",
        description:       opts[:description] || "Cobrança",
        callback_url:      webhook_url
      )
      { "id" => response.id, "status" => response.status }
    rescue DlocalGo::Error => e
      raise GatewayError.new(e.message, code: e.error_code)
    end

    private

    def build_payer(customer, country = "BR")
      {
        name:           customer.name,
        email:          customer.email,
        document:       customer.document,
        user_reference: customer.external_id || customer.id.to_s,
        address:        { country: country }
      }
    end

    def webhook_url
      "#{Rails.application.routes.url_helpers.root_url}webhooks/dlocal_go"
    end
  end
end
