class Superadmin::AccountsController < Superadmin::BaseController
  before_action :set_account, only: [:show, :edit, :update, :suspend, :activate]

  def index
    accounts = Account.order(created_at: :desc)
    render inertia: "Superadmin/Accounts/Index", props: {
      accounts: accounts.map { |a| serialize(a) }
    }
  end

  def show
    ActsAsTenant.with_tenant(@account) do
      render inertia: "Superadmin/Accounts/Show", props: {
        account:  serialize(@account),
        members:  @account.account_users.includes(:user).map { |au|
          {
            id:    au.user.id,
            name:  au.user.name,
            email: au.user.email,
            role:  au.role,
          }
        },
        stats: {
          plans_count:     Plan.count,
          customers_count: Customer.count,
          api_keys_count:  ApiKey.where(active: true).count,
        }
      }
    end
  end

  def edit
    render inertia: "Superadmin/Accounts/Edit", props: {
      account: serialize(@account),
      errors:  {}
    }
  end

  def update
    if @account.update(account_params)
      redirect_to superadmin_account_path(@account), notice: "Conta atualizada."
    else
      render inertia: "Superadmin/Accounts/Edit", props: {
        account: serialize(@account),
        errors:  @account.errors.as_json
      }
    end
  end

  def suspend
    @account.update!(status: "suspended")
    redirect_to superadmin_account_path(@account), notice: "Conta suspensa."
  end

  def activate
    @account.update!(status: "active")
    redirect_to superadmin_account_path(@account), notice: "Conta reativada."
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name)
  end

  def serialize(a)
    {
      id:         a.id,
      name:       a.name,
      slug:       a.slug,
      status:     a.status,
      created_at: a.created_at.strftime("%d/%m/%Y"),
    }
  end
end
