class ApplicationController < ActionController::Base
  set_current_tenant_through_filter
  before_action :authenticate_user!
  before_action :set_tenant

  inertia_share do
    {
      auth:  {
        user:    if current_user
                   {
                     id:    current_user.id,
                     name:  current_user.name,
                     email: current_user.email,
                     role:  current_user.role
                   }
                 end,
        account: if current_user
                   {
                     id:   current_user.account.id,
                     name: current_user.account.name,
                     slug: current_user.account.slug
                   }
                 end
      },
      flash: {
        notice: flash[:notice],
        alert:  flash[:alert],
        token:  flash[:token]
      }
    }
  end

  private

  def set_tenant
    return unless current_user

    set_current_tenant(current_user.account)
  end

  def current_account
    current_user.account
  end
  helper_method :current_account
end
