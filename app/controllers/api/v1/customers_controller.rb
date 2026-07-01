class Api::V1::CustomersController < Api::V1::BaseController
  def create
    external_id = params.require(:external_id)

    # Idempotente: se já existe identidade para este external_id, retorna o cliente
    existing = CustomerIdentity.find_customer(
      integration: @current_integration,
      external_id: external_id
    )

    return render json: serialize(existing, external_id), status: :ok if existing

    customer = ActsAsTenant.with_tenant(@current_account) do
      Customer.find_or_initialize_by(email: params.require(:email).to_s.downcase.strip)
    end

    customer.assign_attributes(
      name:     params[:name],
      document: params[:document],
      country:  params[:country] || "BR",
      phone:    params[:phone]
    )
    customer.status ||= "active"

    unless customer.save
      render json: { errors: customer.errors.as_json }, status: :unprocessable_entity
      return
    end

    customer.set_identity!(integration: @current_integration, external_id: external_id)

    render json: serialize(customer, external_id), status: :created
  end

  private

  def serialize(customer, external_id)
    {
      external_id: external_id,
      id:          customer.id,
      name:        customer.name,
      email:       customer.email,
      document:    customer.document,
      phone:       customer.phone,
      country:     customer.country,
      status:      customer.status
    }
  end
end
