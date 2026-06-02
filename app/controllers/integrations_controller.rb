class IntegrationsController < ApplicationController
  before_action :require_admin!
  before_action :set_integration, only: %i[show edit update destroy]

  def index
    @integrations = Integration.order(name: :asc)
  end

  def new
    @integration = Integration.new
    @events      = Integration::AVAILABLE_EVENTS
  end

  def create
    @integration = Integration.new(integration_params)

    if @integration.save
      redirect_to @integration, notice: "Integração criada. Guarde o secret mostrado abaixo."
    else
      @events = Integration::AVAILABLE_EVENTS
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @events = Integration::AVAILABLE_EVENTS
  end

  def edit
    @events = Integration::AVAILABLE_EVENTS
  end

  def update
    if @integration.update(integration_params)
      redirect_to @integration, notice: "Integração atualizada."
    else
      @events = Integration::AVAILABLE_EVENTS
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @integration.update!(active: false)
    redirect_to integrations_path, notice: "Integração desativada."
  end

  private

  def set_integration
    @integration = Integration.find(params[:id])
  end

  def integration_params
    params.require(:integration).permit(
      :name, :url, :active, :retry_count, events: []
    )
  end

  def require_admin!
    redirect_to root_path, alert: "Acesso negado." unless current_user.admin?
  end
end
