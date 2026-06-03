class ApiKeysController < ApplicationController
  before_action :require_admin!

  def index
    @api_keys = current_account.api_keys.order(created_at: :desc)
  end

  def create
    _api_key, token_raw = ApiKey.generate!(
      account:    current_account,
      name:       params[:name],
      expires_at: params[:expires_at].presence
    )
    flash[:token] = token_raw
    redirect_to api_keys_path
  end

  def destroy
    current_account.api_keys.find(params[:id]).revoke!
    redirect_to api_keys_path, notice: "Chave revogada com sucesso."
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Acesso negado." unless current_user.admin?
  end
end
