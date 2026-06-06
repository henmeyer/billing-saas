class ApplicationController < ActionController::Base
  set_current_tenant_through_filter
  before_action :authenticate_user!
  before_action :set_tenant

  inertia_share do
    {
      auth: {
        user: current_user ? {
          id:           current_user.id,
          name:         current_user.name,
          email:        current_user.email,
          role:         current_account_user&.role,
          superadmin:   current_user.superadmin?,
          impersonating: impersonating?,
        } : nil,
        account: current_account ? {
          id:   current_account.id,
          name: current_account.name,
          slug: current_account.slug,
        } : nil,
        accounts: current_user && !current_user.superadmin? ? user_accounts_list : [],
      },
      flash: {
        notice: flash[:notice],
        alert:  flash[:alert],
        token:  flash[:token],
      }
    }
  end

  private

  def set_tenant
    return if current_user&.superadmin? && current_account.nil?
    set_current_tenant(current_account)
  end

  def current_account
    @current_account ||= begin
      if session[:current_account_id]
        if current_user&.superadmin?
          Account.find_by(id: session[:current_account_id])
        else
          current_user.accounts.find_by(id: session[:current_account_id])
        end
      elsif !current_user&.superadmin?
        current_user&.accounts&.first
      end
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
    unless current_user&.superadmin?
      redirect_to root_path, alert: "Acesso negado."
    end
  end

  def require_admin!
    unless current_user&.superadmin? || current_account_user&.admin?
      redirect_to root_path, alert: "Acesso negado."
    end
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
end
