class Superadmin::ImpersonationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:enter]
  skip_before_action :set_tenant,         only: [:enter]

  def enter
    token     = params[:token].to_s
    redis_key = "impersonation:#{token}"
    redis     = Redis.new(url: ENV["REDIS_URL"])
    raw       = redis.get(redis_key)

    unless raw
      redirect_to new_user_session_path, alert: "Link de impersonação inválido ou expirado."
      return
    end

    data         = JSON.parse(raw)
    user         = User.find_by(id: data["user_id"])
    superadmin   = SuperAdmin.find_by(id: data["superadmin_id"])

    unless user && superadmin
      redirect_to new_user_session_path, alert: "Usuário não encontrado."
      return
    end

    redis.del(redis_key)

    sign_in(user, scope: :user)
    session[:impersonator_id] = superadmin.id
    session[:current_account_id] = user.accounts.first&.id

    Rails.logger.info(
      "[SUPERADMIN] #{superadmin.email} started impersonating #{user.email}"
    )

    redirect_to root_path, notice: "Entrando como #{user.name}."
  end

  def stop
    superadmin_id = session.delete(:impersonator_id)
    session.delete(:current_account_id)

    superadmin = SuperAdmin.find_by(id: superadmin_id)

    if superadmin
      sign_in(superadmin, scope: :user)
      redirect_to superadmin_root_path, notice: "Impersonação encerrada."
    else
      sign_out(:user)
      redirect_to new_user_session_path
    end
  end
end
