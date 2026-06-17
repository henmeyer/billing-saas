class Superadmin::UsersController < Superadmin::BaseController
  def index
    users = User.where(type: nil)
                .includes(:account_users, :accounts)
                .order(created_at: :desc)

    render inertia: "Superadmin/Users/Index", props: {
      users: users.map { |u| serialize(u) }
    }
  end

  def show
    user = User.find(params[:id])
    render inertia: "Superadmin/Users/Show", props: {
      user:     serialize(user),
      accounts: user.accounts.map do |a|
        au = user.account_users.find_by(account: a)
        {
          id:     a.id,
          name:   a.name,
          slug:   a.slug,
          status: a.status,
          role:   au&.role
        }
      end
    }
  end

  def new
    render inertia: "Superadmin/Users/New", props: {
      accounts: Account.order(:name).map { |a| { id: a.id, name: a.name } },
      errors:   {}
    }
  end

  def create
    ActiveRecord::Base.transaction do
      user = User.new(
        name:                  params[:name],
        email:                 params[:email],
        password:              params[:password],
        password_confirmation: params[:password_confirmation]
      )

      unless user.save
        render inertia: "Superadmin/Users/New", props: {
          accounts: Account.order(:name).map { |a| { id: a.id, name: a.name } },
          errors:   user.errors.full_messages
        }
        return
      end

      if params[:account_id].present?
        account = Account.find(params[:account_id])
        account.account_users.create!(user: user, role: params[:role] || "member")
      end

      redirect_to superadmin_user_path(user), notice: "Usuário criado com sucesso."
    end
  rescue StandardError => e
    render inertia: "Superadmin/Users/New", props: {
      accounts: Account.order(:name).map { |a| { id: a.id, name: a.name } },
      errors:   [e.message]
    }
  end

  def impersonate
    user = User.find(params[:id])

    token     = SecureRandom.hex(32)
    redis_key = "impersonation:#{token}"

    Redis.new(url: ENV.fetch("REDIS_URL", nil)).setex(
      redis_key,
      30.minutes.to_i,
      { superadmin_id: current_user.id, user_id: user.id }.to_json
    )

    Rails.logger.info(
      "[SUPERADMIN] #{current_user.email} impersonating #{user.email}"
    )

    redirect_to impersonation_enter_path(token: token)
  end

  private

  def serialize(u)
    {
      id:             u.id,
      name:           u.name,
      email:          u.email,
      accounts_count: u.accounts.count,
      created_at:     u.created_at.strftime("%d/%m/%Y")
    }
  end
end
