class Imports::FetchStripeService
  def initialize(gateway)
    Stripe.api_key = gateway.api_key
  end

  def call
    customers = fetch_all_customers
    enrich_with_subscriptions(customers)
  end

  private

  def fetch_all_customers
    customers = []
    last_id   = nil

    loop do
      params = { limit: 100 }
      params[:starting_after] = last_id if last_id

      response = Stripe::Customer.list(params)
      customers.concat(response.data)

      break unless response.has_more

      last_id = response.data.last.id
    end

    customers
  end

  def enrich_with_subscriptions(customers)
    customers.map do |customer|
      active_sub = fetch_active_subscription(customer.id)

      {
        gateway_id:   customer.id,
        name:         customer.name,
        email:        customer.email,
        document:     customer.metadata["document"],
        phone:        customer.phone,
        external_ref: customer.metadata["external_id"],
        subscription: if active_sub
                        {
                          gateway_subscription_id: active_sub.id,
                          status:                  "active",
                          price_id:                active_sub.items.data.first&.price&.id,
                          amount:                  active_sub.items.data.first&.price&.unit_amount,
                          currency:                active_sub.currency,
                          interval:                active_sub.items.data.first&.price&.recurring&.interval,
                          current_period_end:      Time.at(active_sub.current_period_end).iso8601
                        }
                      end
      }
    end
  end

  def fetch_active_subscription(customer_id)
    subs = Stripe::Subscription.list(
      customer: customer_id,
      status:   "active",
      limit:    1
    )
    subs.data.first
  rescue StandardError
    nil
  end
end
