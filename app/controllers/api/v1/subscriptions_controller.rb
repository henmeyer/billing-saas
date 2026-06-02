class Api::V1::SubscriptionsController < Api::V1::BaseController
  def show
    customer     = find_customer!
    subscription = customer.active_subscription

    unless subscription
      render json: { error: "Sem assinatura ativa" }, status: :not_found
      return
    end

    render json: {
      customer_id:        params[:external_id],
      plan:               {
        id:            subscription.plan.id,
        name:          subscription.plan.name,
        billing_cycle: subscription.plan.billing_cycle,
        price_cents:   subscription.plan.price_cents
      },
      status:             subscription.status,
      gateway:            subscription.gateway,
      current_period_end: subscription.current_period_end&.iso8601,
      started_at:         subscription.started_at&.iso8601
    }
  end

  private

  def find_customer!
    customer = current_account.customers.find_by(external_id: params[:external_id])
    unless customer
      render json: { error: "Cliente não encontrado" }, status: :not_found
      raise ActionController::RoutingError, "not found"
    end
    customer
  end
end
