class Api::V1::CreditsController < Api::V1::BaseController
  def show
    return unless (customer = find_customer!)
    period   = customer.current_period

    unless period
      render json: { error: "Sem assinatura ativa" }, status: :unprocessable_entity
      return
    end

    snapshots = period.credit_snapshots
                      .includes(:credit_type)
                      .index_by { |s| s.credit_type.key }

    render json: {
      customer_id: params[:external_id],
      credits:     snapshots.transform_values do |s|
        {
          used:          s.used,
          limit:         s.limit,
          balance:       s.balance,
          usage_percent: s.usage_percent,
          synced_at:     s.synced_at&.iso8601
        }
      end
    }
  end

  def report
    return unless (customer = find_customer!)
    period   = customer.current_period

    unless period
      render json: { error: "Sem assinatura ativa" }, status: :unprocessable_entity
      return
    end

    credit_type = CreditType.find_by(key: params[:credit_type])
    unless credit_type
      render json:   { error: "Tipo de crédito '#{params[:credit_type]}' não encontrado" },
             status: :not_found
      return
    end

    used  = params[:used].to_i
    limit = params[:limit]&.to_i ||
            customer.active_subscription
                    &.plan
                    &.plan_credits
                    &.find_by(credit_type: credit_type)
                    &.quantity || 0

    snapshot = period.credit_snapshots.find_or_initialize_by(
      credit_type: credit_type
    )
    snapshot.update!(used: used, limit: limit, synced_at: Time.current)

    Credits::CheckThresholdsService.call(customer, snapshot)

    render json: {
      balance:       snapshot.balance,
      usage_percent: snapshot.usage_percent,
      status:        snapshot.balance.positive? ? "ok" : "depleted"
    }
  end

  private

  def find_customer!
    customer = current_account.customers.find_by(external_id: params[:external_id])
    unless customer
      render json: { error: "Cliente não encontrado" }, status: :not_found
      return nil
    end
    customer
  end
end
