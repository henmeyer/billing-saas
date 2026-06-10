class Api::V1::BaseController < ActionController::API
  before_action :authenticate_integration_api_key!

  attr_reader :current_integration_api_key,
              :current_integration,
              :current_account

  private

  def authenticate_integration_api_key!
    raw_token = request.headers["Authorization"]&.sub("Bearer ", "")

    if raw_token&.start_with?("billing_") &&
       !raw_token.start_with?(IntegrationApiKey::PREFIX)
      render json: {
        error: "Esta é uma API Key de conta e não pode ser usada aqui. " \
               "Use a API Key da integração correspondente " \
               "(Configurações → Integrações → API Keys)."
      }, status: :unauthorized
      return
    end

    unless raw_token
      render json: { error: "Token não informado" }, status: :unauthorized
      return
    end

    @current_integration_api_key = IntegrationApiKey.find_by_token(raw_token)

    unless @current_integration_api_key&.active? &&
           !@current_integration_api_key.expired?
      render json: { error: "Token inválido ou expirado" }, status: :unauthorized
      return
    end

    @current_integration = ActsAsTenant.without_tenant { @current_integration_api_key.integration }
    @current_account     = @current_integration.account
    ActsAsTenant.current_tenant = @current_account
    @current_integration_api_key.touch_last_used!
  end

  def find_customer_by_external_id!(external_id)
    customer = CustomerIdentity.find_customer(
      integration: @current_integration,
      external_id: external_id
    )

    unless customer
      render json: {
        error: "Cliente '#{external_id}' não encontrado nesta integração."
      }, status: :not_found
      return nil
    end

    customer
  end
end
