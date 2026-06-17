class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :authenticate_user!, only: [:new, :create], raise: false
  skip_before_action :set_tenant

  def new
    render inertia: "Auth/Register", props: { errors: [] }
  end

  def create
    user_params = params[:user] || params

    result = Accounts::CreateService.call(
      company_name:          user_params[:company_name],
      name:                  user_params[:name],
      email:                 user_params[:email],
      password:              user_params[:password],
      password_confirmation: user_params[:password_confirmation]
    )

    if result.success?
      sign_in(result.user)
      redirect_to root_path, notice: "Conta criada com sucesso!"
    else
      render inertia: "Auth/Register", props: { errors: result.errors }
    end
  end
end
