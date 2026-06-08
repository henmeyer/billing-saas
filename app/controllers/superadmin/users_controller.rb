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
      accounts: user.accounts.map { |a|
        au = user.account_users.find_by(account: a)
        {
          id:     a.id,
          name:   a.name,
          slug:   a.slug,
          status: a.status,
          role:   au&.role
        }
      }
    }
  end

  def impersonate
    user = User.find(params[:id])

    token     = SecureRandom.hex(32)
    redis_key = "impersonation:#{token}"

    Redis.new(url: ENV["REDIS_URL"]).setex(
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
      created_at:     u.created_at.strftime("%d/%m/%Y"),
    }
  end
end
