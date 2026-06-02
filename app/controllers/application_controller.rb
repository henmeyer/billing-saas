class ApplicationController < ActionController::Base
  set_current_tenant_through_filter
  before_action :authenticate_user!
  before_action :set_tenant

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
