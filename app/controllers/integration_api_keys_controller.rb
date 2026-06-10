class IntegrationApiKeysController < ApplicationController
  before_action :require_admin!
  before_action :set_integration

  def index
    keys = @integration.integration_api_keys.order(created_at: :desc)
    render inertia: "IntegrationApiKeys/Index", props: {
      integration: serialize_integration(@integration),
      api_keys:    keys.map { |k| serialize_key(k) }
    }
  end

  def create
    _key, token_raw = IntegrationApiKey.generate!(
      integration: @integration,
      name:        params[:name],
      expires_at:  params[:expires_at].presence
    )

    flash[:token] = token_raw
    redirect_to integration_path(@integration), notice: "Chave criada com sucesso."
  end

  def destroy
    @integration.integration_api_keys.find(params[:id]).revoke!
    redirect_to integration_path(@integration), notice: "Chave revogada."
  end

  private

  def set_integration
    @integration = Integration.find(params[:integration_id])
  end

  def serialize_integration(integration)
    { id: integration.id, name: integration.name, url: integration.url }
  end

  def serialize_key(api_key)
    used_at = api_key.last_used_at
    {
      id:           api_key.id,
      name:         api_key.name,
      last_four:    api_key.last_four,
      active:       api_key.active,
      last_used_at: used_at ? "#{helpers.time_ago_in_words(used_at)} atrás" : "Nunca",
      expires_at:   api_key.expires_at&.strftime("%d/%m/%Y")
    }
  end
end
