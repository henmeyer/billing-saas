class ApiKeysController < ApplicationController
  before_action :require_admin!

  def index
    api_keys = current_account.api_keys.order(created_at: :desc).map do |k|
      {
        id:           k.id,
        name:         k.name,
        last_four:    k.last_four,
        active:       k.active,
        last_used_at: k.last_used_at ? "#{time_ago_in_words(k.last_used_at)} atrás" : 'Nunca',
        expires_at:   k.expires_at&.strftime('%d/%m/%Y'),
      }
    end

    render inertia: 'ApiKeys/Index', props: { api_keys: }
  end

  def create
    _api_key, token_raw = ApiKey.generate!(
      account:    current_account,
      name:       params[:name],
      expires_at: params[:expires_at].presence
    )
    flash[:token] = token_raw
    redirect_to api_keys_path, notice: 'Chave criada.'
  end

  def destroy
    current_account.api_keys.find(params[:id]).revoke!
    redirect_to api_keys_path, notice: 'Chave revogada.'
  end

  private

  def require_admin!
    redirect_to root_path, alert: 'Acesso negado.' unless current_user.admin?
  end
end
