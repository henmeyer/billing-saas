class Superadmin::DashboardController < Superadmin::BaseController
  def index
    render inertia: "Superadmin/Dashboard/Index", props: {
      stats:           {
        accounts_count:     Account.count,
        users_count:        User.where(type: nil).count,
        super_admins_count: SuperAdmin.count,
        active_accounts:    Account.where(status: "active").count,
        suspended_accounts: Account.where(status: "suspended").count
      },
      recent_accounts: Account.order(created_at: :desc).limit(10).map do |a|
        {
          id:         a.id,
          name:       a.name,
          slug:       a.slug,
          status:     a.status,
          created_at: a.created_at.strftime("%d/%m/%Y")
        }
      end
    }
  end
end
