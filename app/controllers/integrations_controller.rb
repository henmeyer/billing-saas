class IntegrationsController < ApplicationController
  before_action :require_admin!
  before_action :set_integration, only: [:show, :edit, :update, :destroy]

  def index
    integrations = Integration.order(name: :asc).map { |i| serialize_integration(i) }
    render inertia: 'Integrations/Index', props: { integrations: }
  end

  def new
    render inertia: 'Integrations/Form', props: {
      integration:      {},
      available_events: Integration::AVAILABLE_EVENTS,
      license_types:    serialize_license_types,
      credit_types:     serialize_credit_types,
      errors:           {}
    }
  end

  def create
    integration = Integration.new(integration_params)
    if integration.save
      sync_field_configs(integration)
      redirect_to integrations_path, notice: 'Integração criada.'
    else
      render inertia: 'Integrations/Form', props: {
        integration:      integration_params,
        available_events: Integration::AVAILABLE_EVENTS,
        license_types:    serialize_license_types,
        credit_types:     serialize_credit_types,
        errors:           integration.errors.as_json
      }
    end
  end

  def edit
    render inertia: 'Integrations/Form', props: {
      integration:      serialize_integration(@integration),
      available_events: Integration::AVAILABLE_EVENTS,
      license_types:    serialize_license_types,
      credit_types:     serialize_credit_types,
      errors:           {}
    }
  end

  def update
    if @integration.update(integration_params)
      sync_field_configs(@integration)
      redirect_to integrations_path, notice: 'Integração atualizada.'
    else
      render inertia: 'Integrations/Form', props: {
        integration:      serialize_integration(@integration),
        available_events: Integration::AVAILABLE_EVENTS,
        license_types:    serialize_license_types,
        credit_types:     serialize_credit_types,
        errors:           @integration.errors.as_json
      }
    end
  end

  def destroy
    @integration.update!(active: false)
    redirect_to integrations_path, notice: 'Integração desativada.'
  end

  private

  def set_integration
    @integration = Integration.find(params[:id])
  end

  def integration_params
    params.require(:integration).permit(:name, :url, :active, :retry_count, events: [])
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
  end

  def serialize_integration(i)
    {
      id:               i.id,
      name:             i.name,
      url:              i.url,
      events:           i.events,
      active:           i.active,
      retry_count:      i.retry_count,
      last_error_at:    i.last_error_at&.strftime('%d/%m/%Y %H:%M'),
      license_type_ids: i.integration_field_configs
                         .where(field_type: "license")
                         .pluck(:license_type_id),
      credit_type_ids:  i.integration_field_configs
                         .where(field_type: "credit")
                         .pluck(:credit_type_id),
    }
  end

  def serialize_license_types
    LicenseType.all.map { |lt| { id: lt.id, key: lt.key, label: lt.label } }
  end

  def serialize_credit_types
    CreditType.all.map { |ct| { id: ct.id, key: ct.key, label: ct.label } }
  end

  def require_admin!
    redirect_to root_path, alert: 'Acesso negado.' unless current_user.admin?
  end
end
