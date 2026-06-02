module Gateways
  class AsaasAdapter < Base
    BASE_URL = "https://api.asaas.com/v3".freeze

    def initialize
      gateway = ActsAsTenant.current_tenant
                            .payment_gateways
                            .find_by!(provider: "asaas")
      @api_key = gateway.api_key
    end

    def create_customer(customer)
      response = post("/customers", {
        name:              customer.name,
        email:             customer.email,
        cpfCnpj:           customer.document,
        phone:             customer.phone,
        externalReference: customer.external_id
      })
      customer.gateway_data["asaas"] ||= {}
      customer.gateway_data["asaas"]["customer_id"] = response["id"]
      customer.save!
      response
    end

    def create_subscription(customer, plan)
      post("/subscriptions", {
        customer:          customer.gateway_data.dig("asaas", "customer_id"),
        billingType:       plan.gateway_data.dig("asaas", "billing_type") || "BOLETO",
        value:             plan.price_cents / 100.0,
        nextDueDate:       Date.tomorrow.strftime("%Y-%m-%d"),
        cycle:             asaas_cycle(plan.billing_cycle),
        description:       plan.name,
        externalReference: plan.id.to_s
      })
    end

    def cancel_subscription(gateway_sub_id)
      response = HTTParty.delete(
        "#{BASE_URL}/subscriptions/#{gateway_sub_id}",
        headers: headers
      )
      raise GatewayError, response.body unless response.success?
      response.parsed_response
    end

    def update_subscription(gateway_sub_id, new_plan)
      post("/subscriptions/#{gateway_sub_id}", {
        value: new_plan.price_cents / 100.0,
        cycle: asaas_cycle(new_plan.billing_cycle)
      })
    end

    private

    def asaas_cycle(billing_cycle)
      { "monthly" => "MONTHLY", "yearly" => "YEARLY" }.fetch(billing_cycle, "MONTHLY")
    end

    def post(path, body)
      response = HTTParty.post(
        "#{BASE_URL}#{path}",
        headers: headers,
        body:    body.to_json
      )
      raise GatewayError, response["errors"].to_s unless response.success?
      response.parsed_response
    end

    def headers
      {
        "access_token" => @api_key,
        "Content-Type" => "application/json"
      }
    end
  end
end
