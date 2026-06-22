class ProfileController < ApplicationController
  def show
    render inertia: "Profile/Show", props: { user: serialize_user }
  end

  def update
    if params[:section] == "password"
      update_password
    else
      update_info
    end
  end

  def destroy_avatar
    current_user.avatar.purge
    redirect_to profile_path, notice: "Foto removida.", status: :see_other
  end

  private

  def update_info
    attrs = { name: params[:name] }
    attrs[:avatar] = params[:avatar] if params[:avatar].present?

    if current_user.update(attrs)
      redirect_to profile_path, notice: "Perfil atualizado.", status: :see_other
    else
      redirect_to profile_path,
                  alert:  current_user.errors.full_messages.join(", "),
                  status: :see_other
    end
  end

  def update_password
    unless current_user.valid_password?(params[:current_password])
      return redirect_to profile_path, alert: "Senha atual incorreta.", status: :see_other
    end

    if params[:password].blank?
      return redirect_to profile_path, alert: "Nova senha não pode ser vazia.", status: :see_other
    end

    if params[:password] != params[:password_confirmation]
      return redirect_to profile_path, alert:  "Confirmação de senha não confere.",
                                       status: :see_other
    end

    if params[:password].length < 8
      return redirect_to profile_path, alert:  "Senha deve ter no mínimo 8 caracteres.",
                                       status: :see_other
    end

    current_user.update!(
      password:              params[:password],
      password_confirmation: params[:password_confirmation]
    )

    bypass_sign_in(current_user)

    redirect_to profile_path, notice: "Senha alterada com sucesso.", status: :see_other
  end

  def serialize_user
    {
      id:         current_user.id,
      name:       current_user.name,
      email:      current_user.email,
      avatar_url: current_user.avatar_url,
      initials:   current_user.initials,
      created_at: current_user.created_at.strftime("%d/%m/%Y")
    }
  end
end
