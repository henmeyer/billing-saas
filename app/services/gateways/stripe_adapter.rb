module Gateways
  class StripeAdapter < Base
    def initialize
      gateway = ActsAsTenant.current_tenant
                            .payment_gateways
                            .find_by!(provider: "stripe")
      Stripe.api_key = gateway.api_key
    end

    def create_customer(customer)
      result = Stripe::Customer.create(
        email:    customer.email,
        name:     customer.name,
        metadata: { external_id: customer.external_id }
      )
      customer.gateway_data["stripe"] ||= {}
      customer.gateway_data["stripe"]["customer_id"] = result.id
      customer.save!
      result
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end

    def create_subscription(customer, plan, amount_cents: nil)
      price_id = if amount_cents
        price = Stripe::Price.create(
          currency:    "brl",
          unit_amount: amount_cents,
          recurring:   { interval: plan.billing_cycle == "yearly" ? "year" : "month" },
          product:     plan.gateway_data.dig("stripe", "product_id")
        )
        price.id
      else
        plan.gateway_data.dig("stripe", "price_id") ||
          raise(GatewayError, "Plano não configurado no Stripe (falta price_id)")
      end

      Stripe::Subscription.create(
        customer: customer.gateway_data.dig("stripe", "customer_id"),
        items:    [{ price: price_id }],
        metadata: { plan_id: plan.id, customer_id: customer.id }
      )
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end

    def cancel_subscription(gateway_sub_id)
      Stripe::Subscription.cancel(gateway_sub_id)
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end

    def update_subscription(gateway_sub_id, new_plan, amount_cents:)
      sub      = Stripe::Subscription.retrieve(gateway_sub_id)
      price_id = new_plan.gateway_data.dig("stripe", "price_id")
      raise GatewayError, "Novo plano não configurado no Stripe" unless price_id

      Stripe::Subscription.update(gateway_sub_id, {
                                    items: [{ id: sub.items.data[0].id, price: price_id }]
                                  })
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end

    def test_connection
      Stripe::Balance.retrieve
      { success: true, message: "Conexão com Stripe OK" }
    rescue Stripe::AuthenticationError => e
      { success: false, message: "API key inválida: #{e.message}" }
    rescue Stripe::StripeError => e
      { success: false, message: "Erro Stripe: #{e.message}" }
    end
  end
end
