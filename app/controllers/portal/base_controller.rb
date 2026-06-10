class Portal::BaseController < ActionController::Base
  layout "portal"
  protect_from_forgery with: :null_session

  before_action :authenticate_portal!
  before_action :set_referrer_policy

  helper_method :current_customer,
                :current_integration,
                :portal_config,
                :portal_token

  inertia_share do
    {
      flash:        { notice: flash[:notice], alert: flash[:alert] },
      customer:     current_customer ? { name: current_customer.name, email: current_customer.email } : {},
      portal_token: portal_token
    }
  end

  private

  def portal_token
    params[:token]
  end

  def authenticate_portal!
    unless current_portal_session&.valid_session?
      redirect_to portal_expired_path
    end
  end

  def current_portal_session
    return @current_portal_session if defined?(@current_portal_session)
    @current_portal_session = PortalSession.find_by_token(portal_token)
  end

  def current_customer
    @current_customer ||= ActsAsTenant.without_tenant do
      current_portal_session&.customer
    end
  end

  def current_integration
    @current_integration ||= ActsAsTenant.without_tenant do
      current_portal_session&.integration
    end
  end

  def current_account
    @current_account ||= current_integration&.account
  end

  def portal_config
    @portal_config ||= current_integration&.portal_config || {}
  end

  def set_tenant!
    ActsAsTenant.current_tenant = current_account
  end

  def current_subscription
    @current_subscription ||= begin
      set_tenant!
      current_customer.subscriptions
                      .active
                      .where(integration_id: current_integration.id)
                      .first
    end
  end

  def branding
    {
      logo_url:      current_integration.portal_logo_url,
      primary_color: current_integration.portal_primary_color,
      company_name:  current_integration.name
    }
  end

  # Helpers de redirect com token
  def portal_redirect_path(route_name = :portal_dashboard, **opts)
    send(:"#{route_name}_path", token: portal_token, **opts)
  end

  # Evita que o token vaze no header Referer ao clicar links externos
  def set_referrer_policy
    response.set_header("Referrer-Policy", "no-referrer")
  end
end
