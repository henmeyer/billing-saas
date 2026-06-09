class Imports::FetchAsaasService
  SANDBOX_URL    = "https://api-sandbox.asaas.com/v3".freeze
  PRODUCTION_URL = "https://api.asaas.com/v3".freeze
  PAGE_SIZE      = 100

  def initialize(gateway)
    @api_key  = gateway.api_key
    @base_url = gateway.gateway_data.fetch("sandbox", true) ? SANDBOX_URL : PRODUCTION_URL
  end

  def call
    customers = fetch_all_customers
    enrich_with_subscriptions(customers)
  end

  private

  def fetch_all_customers
    customers = []
    offset    = 0

    loop do
      response = get("/customers", limit: PAGE_SIZE, offset: offset)
      data     = response["data"] || []
      customers.concat(data)

      break if data.length < PAGE_SIZE

      offset += PAGE_SIZE
    end

    customers
  end

  def enrich_with_subscriptions(customers)
    customers.map do |customer|
      subs       = fetch_subscriptions_for(customer["id"])
      active_sub = subs.find { |s| s["status"] == "ACTIVE" }

      {
        gateway_id:   customer["id"],
        name:         customer["name"],
        email:        customer["email"],
        document:     customer["cpfCnpj"],
        phone:        customer["phone"],
        external_ref: customer["externalReference"],
        subscription: if active_sub
                        {
                          gateway_subscription_id: active_sub["id"],
                          status:                  "active",
                          billing_type:            active_sub["billingType"],
                          value:                   (active_sub["value"].to_f * 100).to_i,
                          cycle:                   active_sub["cycle"]&.downcase,
                          next_due_date:           active_sub["nextDueDate"]
                        }
                      end
      }
    end
  end

  def fetch_subscriptions_for(customer_id)
    response = get("/subscriptions", customer: customer_id, status: "ACTIVE")
    response["data"] || []
  rescue StandardError
    []
  end

  def get(path, params = {})
    response = HTTParty.get(
      "#{@base_url}#{path}",
      query:   params,
      headers: {
        "access_token" => @api_key,
        "Content-Type" => "application/json"
      }
    )
    raise "Asaas API error: #{response.code}" unless response.success?

    response.parsed_response
  end
end
