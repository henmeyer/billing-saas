class AccountUsersController < ApplicationController
  before_action :set_account_user, only: %i[edit update destroy]

  def index
    account_users = policy_scope(AccountUser)
                    .includes(user: { avatar_attachment: :blob })
                    .order(:role)
                    .map { |au| serialize_account_user(au) }

    render inertia: "AccountUsers/Index", props: { account_users: }
  end

  def new
    authorize AccountUser

    render inertia: "AccountUsers/Form", props: {
      account_user: { email: "", role: "member" },
      errors:       {}
    }
  end

  def create
    authorize AccountUser

    if assignable_roles.exclude?(params[:role])
      return render inertia: "AccountUsers/Form", props: {
        account_user: { email: params[:email], role: params[:role] },
        errors:       { role: ["Você não pode atribuir este nível de permissão."] }
      }
    end

    user = User.find_by(email: params[:email])

    if user.nil?
      return render inertia: "AccountUsers/Form", props: {
        account_user: { email: params[:email], role: params[:role] },
        errors:       { email: ["Usuário não encontrado."] }
      }
    end

    account_user = current_account.account_users.new(user:, role: params[:role])

    if account_user.save
      redirect_to account_users_path, notice: "Colaborador adicionado."
    else
      render inertia: "AccountUsers/Form", props: {
        account_user: { email: params[:email], role: params[:role] },
        errors:       account_user.errors.as_json
      }
    end
  end

  def edit
    authorize @account_user

    render inertia: "AccountUsers/Form", props: {
      account_user: serialize_account_user(@account_user),
      errors:       {}
    }
  end

  def update
    authorize @account_user, :change_role?

    if assignable_roles.exclude?(params[:role])
      return render inertia: "AccountUsers/Form", props: {
        account_user: serialize_account_user(@account_user),
        errors:       { role: ["Você não pode atribuir este nível de permissão."] }
      }
    end

    if @account_user.update(role: params[:role])
      redirect_to account_users_path, notice: "Permissão atualizada."
    else
      render inertia: "AccountUsers/Form", props: {
        account_user: serialize_account_user(@account_user),
        errors:       @account_user.errors.as_json
      }
    end
  end

  def destroy
    authorize @account_user
    @account_user.destroy!
    redirect_to account_users_path, notice: "Colaborador removido."
  end

  private

  def set_account_user
    @account_user = current_account.account_users.find(params[:id])
  end

  def assignable_roles
    return AccountUser::ROLES if current_user.superadmin?

    my_level = current_user.account_user_for(current_account)&.level || 0
    AccountUser::ROLES.select { |role| AccountUser::ROLE_LEVEL[role] < my_level }
  end

  def serialize_account_user(account_user)
    {
      id:    account_user.id,
      role:  account_user.role,
      level: account_user.level,
      user:  {
        id:         account_user.user.id,
        name:       account_user.user.name,
        email:      account_user.user.email,
        avatar_url: account_user.user.avatar_url,
        initials:   account_user.user.initials
      }
    }
  end
end
