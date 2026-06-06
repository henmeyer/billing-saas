class Api::V1::BaseController < ActionController::API
  before_action :authenticate_api_key!

  attr_reader :current_api_key, :current_account

  private

  def authenticate_api_key!
    raw_token = request.headers["Authorization"]&.sub("Bearer ", "")

    unless raw_token
      render json: { error: "Token não informado" }, status: :unauthorized
      return
    end

    @current_api_key = ActsAsTenant.without_tenant { ApiKey.find_by_token(raw_token) }

    unless @current_api_key&.active? && !@current_api_key.expired?
      render json: { error: "Token inválido ou expirado" }, status: :unauthorized
      return
    end

    @current_account = @current_api_key.account
    ActsAsTenant.current_tenant = @current_account
    @current_api_key.touch_last_used!
  end
end
