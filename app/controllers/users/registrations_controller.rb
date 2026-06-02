class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :set_tenant

  def create
    result = Accounts::CreateService.call(
      company_name:          params[:user][:company_name],
      name:                  params[:user][:name],
      email:                 params[:user][:email],
      password:              params[:user][:password],
      password_confirmation: params[:user][:password_confirmation]
    )

    if result.success?
      sign_in(result.user)
      redirect_to root_path, notice: "Conta criada com sucesso!"
    else
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end
end
