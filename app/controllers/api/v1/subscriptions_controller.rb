class Api::V1::SubscriptionsController < Api::V1::BaseController
  def show
    return unless (customer = find_customer_by_external_id!(params[:external_id]))

    integration = resolve_integration
    return unless integration

    subscription = customer.subscriptions
                           .where(status: %w[active trialing past_due])
                           .find_by(integration: integration)

    unless subscription
      render json: {
        error: "Sem assinatura ativa para a integração '#{integration.name}'"
      }, status: :not_found
      return
    end

    render json: {
      customer_id:        params[:external_id],
      integration_id:     subscription.integration_id,
      integration_name:   subscription.integration.name,
      plan:               {
        id:            subscription.plan.id,
        name:          subscription.plan.name,
        billing_cycle: subscription.plan.billing_cycle,
        price_cents:   subscription.price_in_currency,
        currency:      subscription.effective_currency&.code
      },
      status:             subscription.status,
      gateway:            subscription.gateway,
      current_period_end: subscription.current_period_end&.iso8601,
      started_at:         subscription.started_at&.iso8601
    }
  end

  private

  def resolve_integration
    if params[:integration_id].present?
      integration = Integration.find_by(id: params[:integration_id])
      unless integration
        render json: { error: "Integração não encontrada" }, status: :not_found
        return nil
      end
      integration
    else
      @current_integration
    end
  end
end
