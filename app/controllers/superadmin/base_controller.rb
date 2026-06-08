class Superadmin::BaseController < ApplicationController
  before_action :require_superadmin!

  layout false

  private

  def require_superadmin!
    unless current_user&.superadmin?
      redirect_to root_path, alert: "Acesso negado."
    end
  end
end
