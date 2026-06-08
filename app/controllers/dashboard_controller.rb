class DashboardController < ApplicationController
  def index
    return redirect_to superadmin_root_path if current_user.superadmin? && current_account.nil?

    stats = Dashboard::StatsService.call(current_account)
    render inertia: 'Dashboard/Index', props: { stats: }
  end
end
