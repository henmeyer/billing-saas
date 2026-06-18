class ApiKeysController < ApplicationController
  before_action :require_admin!

  def index
    api_keys = policy_scope(current_account.api_keys).order(created_at: :desc).map do |k|
      {
        id:           k.id,
        name:         k.name,
        last_four:    k.last_four,
        active:       k.active,
        last_used_at: k.last_used_at&.strftime("%d/%m/%Y %H:%M") || "Nunca",
        expires_at:   k.expires_at&.strftime("%d/%m/%Y")
      }
    end

    render inertia: "ApiKeys/Index", props: { api_keys: }
  end

  def create
    authorize ApiKey

    _api_key, token_raw = ApiKey.generate!(
      account:    current_account,
      name:       params[:name],
      expires_at: params[:expires_at].presence
    )
    flash[:token] = token_raw
    redirect_to api_keys_path, notice: "Chave criada."
  end

  def destroy
    api_key = current_account.api_keys.find(params[:id])
    authorize api_key

    api_key.revoke!
    redirect_to api_keys_path, notice: "Chave revogada."
  end
end
