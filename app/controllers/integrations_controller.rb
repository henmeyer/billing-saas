class IntegrationsController < ApplicationController
  before_action :set_integration, only: %i[show edit update destroy]

  def index
    integrations = policy_scope(Integration).order(name: :asc).map { |i| serialize_integration(i) }
    render inertia: "Integrations/Index", props: { integrations: }
  end

  def show
    authorize @integration

    keys = @integration.integration_api_keys.order(created_at: :desc)
    render inertia: "Integrations/Show", props: {
      integration: serialize_full(@integration),
      api_keys:    keys.map { |k| serialize_api_key(k) }
    }
  end

  def new
    authorize Integration

    render inertia: "Integrations/Form", props: {
      integration:      {},
      available_events: Integration::AVAILABLE_EVENTS,
      license_types:    serialize_license_types,
      credit_types:     serialize_credit_types,
      feature_types:    serialize_feature_types,
      errors:           {}
    }
  end

  def create
    authorize Integration

    integration = Integration.new(integration_params)
    if integration.save
      sync_field_configs(integration)
      redirect_to integrations_path, notice: "Integração criada."
    else
      render inertia: "Integrations/Form", props: {
        integration:      integration_params,
        available_events: Integration::AVAILABLE_EVENTS,
        license_types:    serialize_license_types,
        credit_types:     serialize_credit_types,
        feature_types:    serialize_feature_types,
        errors:           integration.errors.as_json
      }
    end
  end

  def edit
    authorize @integration

    render inertia: "Integrations/Form", props: {
      integration:      serialize_integration(@integration),
      available_events: Integration::AVAILABLE_EVENTS,
      license_types:    serialize_license_types,
      credit_types:     serialize_credit_types,
      feature_types:    serialize_feature_types,
      errors:           {}
    }
  end

  def update
    authorize @integration

    if @integration.update(integration_params)
      sync_field_configs(@integration)
      redirect_to integrations_path, notice: "Integração atualizada."
    else
      render inertia: "Integrations/Form", props: {
        integration:      serialize_integration(@integration),
        available_events: Integration::AVAILABLE_EVENTS,
        license_types:    serialize_license_types,
        credit_types:     serialize_credit_types,
        feature_types:    serialize_feature_types,
        errors:           @integration.errors.as_json
      }
    end
  end

  def destroy
    authorize @integration

    @integration.update!(active: false)
    redirect_to integrations_path, notice: "Integração desativada."
  end

  private

  def set_integration
    @integration = Integration.find(params[:id])
  end

  def integration_params
    params.require(:integration).permit(
      :name, :url, :active, :retry_count,
      :portal_logo_url, :portal_primary_color,
      events: [],
      portal_config: %i[
        allow_plan_change
        allow_buy_products
        allow_adjust_extras
        show_invoice_history
        allow_cancel
      ]
    )
  end

  def sync_field_configs(integration)
    integration.integration_field_configs.where(field_type: "license").destroy_all
    Array(params[:license_type_ids]).each do |lt_id|
      integration.integration_field_configs.create!(
        license_type_id: lt_id,
        field_type:      "license"
      )
    end

    integration.integration_field_configs.where(field_type: "credit").destroy_all
    Array(params[:credit_type_ids]).each do |ct_id|
      integration.integration_field_configs.create!(
        credit_type_id: ct_id,
        field_type:     "credit"
      )
    end

    integration.integration_field_configs.where(field_type: "feature").destroy_all
    Array(params[:feature_type_ids]).each do |ft_id|
      integration.integration_field_configs.create!(
        feature_type_id: ft_id,
        field_type:      "feature"
      )
    end
  end

  def serialize_integration(integration)
    {
      id:                   integration.id,
      name:                 integration.name,
      url:                  integration.url,
      events:               integration.events,
      active:               integration.active,
      retry_count:          integration.retry_count,
      last_error_at:        integration.last_error_at&.strftime("%d/%m/%Y %H:%M"),
      portal_config:        integration.portal_config,
      portal_logo_url:      integration.portal_logo_url,
      portal_primary_color: integration.portal_primary_color,
      license_type_ids: integration.integration_field_configs
                                   .where(field_type: "license")
                                   .pluck(:license_type_id),
      credit_type_ids:  integration.integration_field_configs
                                   .where(field_type: "credit")
                                   .pluck(:credit_type_id),
      feature_type_ids: integration.integration_field_configs
                                   .where(field_type: "feature")
                                   .pluck(:feature_type_id)
    }
  end

  def serialize_full(integration)
    serialize_integration(integration).merge(secret: integration.secret)
  end

  def serialize_api_key(api_key)
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

  def serialize_license_types
    LicenseType.all.map { |lt| { id: lt.id, key: lt.key, label: lt.label } }
  end

  def serialize_credit_types
    CreditType.all.map { |ct| { id: ct.id, key: ct.key, label: ct.label } }
  end

  def serialize_feature_types
    FeatureType.all.map { |ft| { id: ft.id, key: ft.key, label: ft.label } }
  end
end
