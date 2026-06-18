class ApplicationController < ActionController::Base
  include Pundit::Authorization

  set_current_tenant_through_filter
  before_action :authenticate_user!
  before_action :set_tenant

  after_action :verify_authorized, unless: -> { skip_pundit? || action_name == "index" }
  after_action :verify_policy_scoped, if: -> { !skip_pundit? && action_name == "index" }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :can_policy?

  inertia_share do
    {
      auth:  {
        user:     if current_user
                    {
                      id:            current_user.id,
                      name:          current_user.name,
                      email:         current_user.email,
                      role:          current_account_user&.role,
                      superadmin:    current_user.superadmin?,
                      impersonating: impersonating?,
                      avatar_url:    current_user.avatar_url,
                      initials:      current_user.initials
                    }
                  end,
        account:  if current_account
                    {
                      id:   current_account.id,
                      name: current_account.name,
                      slug: current_account.slug
                    }
                  end,
        accounts: current_user && !current_user.superadmin? ? user_accounts_list : [],
        can:      current_user && current_account ? build_permissions : {}
      },
      flash: {
        notice: flash[:notice],
        alert:  flash[:alert],
        token:  flash[:token]
      }
    }
  end

  def can_policy?(action, record_or_class)
    policy(record_or_class).public_send("#{action}?")
  rescue NoMethodError
    false
  end

  private

  def set_tenant
    return if current_account.nil?

    set_current_tenant(current_account)
  end

  def current_account
    @current_account ||= if session[:current_account_id]
                           if current_user&.superadmin?
                             Account.find_by(id: session[:current_account_id])
                           else
                             current_user.accounts.find_by(id: session[:current_account_id])
                           end
                         else
                           current_user&.accounts&.first
                         end
  end
  helper_method :current_account

  def current_account_user
    return nil if current_user&.superadmin?

    @current_account_user ||= AccountUser.find_by(
      user:    current_user,
      account: current_account
    )
  end
  helper_method :current_account_user

  def impersonating?
    session[:impersonator_id].present?
  end
  helper_method :impersonating?

  def require_superadmin!
    return if current_user&.superadmin?

    redirect_to root_path, alert: "Acesso negado."
  end

  def require_admin!
    return if current_user&.superadmin? || current_account_user&.admin?

    redirect_to root_path, alert: "Acesso negado."
  end

  def user_accounts_list
    current_user.accounts.map do |a|
      au = current_user.account_users.find_by(account: a)
      {
        id:         a.id,
        name:       a.name,
        slug:       a.slug,
        role:       au&.role,
        is_current: a.id == current_account&.id
      }
    end
  end

  def user_not_authorized
    if request.format.json?
      render json: { error: "Acesso negado." }, status: :forbidden
    else
      redirect_to root_path,
                  alert:  "Você não tem permissão para esta ação.",
                  status: :see_other
    end
  end

  # Controllers que não usam Pundit (login, portal, superadmin, api, webhooks)
  def skip_pundit?
    devise_controller? ||
      is_a?(Portal::BaseController) ||
      is_a?(Superadmin::BaseController) ||
      is_a?(Api::V1::BaseController) ||
      is_a?(Webhooks::BaseController) ||
      is_a?(DashboardController) ||
      is_a?(ProfileController)
  end

  def build_permissions
    {
      view_full_dashboard:  DashboardPolicy.new(current_user, nil).full_stats?,

      view_customers:       CustomerPolicy.new(current_user, nil).index?,
      create_customers:     CustomerPolicy.new(current_user, nil).create?,
      manage_customers:     CustomerPolicy.new(current_user, nil).destroy?,

      view_subscriptions:   SubscriptionPolicy.new(current_user, nil).index?,
      create_subscriptions: SubscriptionPolicy.new(current_user, nil).create?,
      cancel_subscriptions: SubscriptionPolicy.new(current_user, nil).cancel?,

      view_plans:           PlanPolicy.new(current_user, nil).index?,
      manage_plans:         PlanPolicy.new(current_user, nil).create?,

      view_products:        ProductPolicy.new(current_user, nil).index?,
      manage_products:      ProductPolicy.new(current_user, nil).create?,

      import_customers:     ImportJobPolicy.new(current_user, nil).create?,

      view_integrations:    IntegrationPolicy.new(current_user, nil).index?,
      manage_integrations:  IntegrationPolicy.new(current_user, nil).create?,

      manage_settings:      PaymentGatewayPolicy.new(current_user, nil).index?,

      view_members:         AccountUserPolicy.new(current_user, nil).index?,
      manage_members:       AccountUserPolicy.new(current_user, nil).create?,

      view_webhook_logs:    WebhookLogPolicy.new(current_user, nil).index?
    }
  end
end
