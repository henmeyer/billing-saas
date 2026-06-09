class Api::V1::LicensesController < Api::V1::BaseController
  def show
    return unless (customer = find_customer!)
    subscription = customer.active_subscription

    unless subscription
      render json: { error: "Sem assinatura ativa" }, status: :unprocessable_entity
      return
    end

    license_usage = customer.metadata["license_usage"] || {}

    licenses = subscription.plan.plan_licenses.includes(:license_type).to_h do |pl|
      used = license_usage[pl.license_type.key].to_i
      [
        pl.license_type.key,
        {
          allocated: pl.quantity,
          used:      used,
          available: pl.unlimited? ? nil : [pl.quantity - used, 0].max,
          unlimited: pl.unlimited?
        }
      ]
    end

    render json: { customer_id: params[:external_id], licenses: }
  end

  def report
    return unless (customer = find_customer!)

    params[:licenses].each do |license_key, used_count|
      customer.metadata["license_usage"] ||= {}
      customer.metadata["license_usage"][license_key] = used_count.to_i
    end
    customer.save!

    render json: { status: "ok", licenses: customer.metadata["license_usage"] }
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
