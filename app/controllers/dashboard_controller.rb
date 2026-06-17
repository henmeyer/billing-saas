class DashboardController < ApplicationController
  FINANCIAL_KEYS = %i[mrr arr revenue_this_month mrr_by_plan].freeze

  def index
    return redirect_to superadmin_root_path if current_user.superadmin? && current_account.nil?

    stats = Dashboard::StatsService.call(current_account)
    stats = stats.except(*FINANCIAL_KEYS) unless policy(:dashboard).full_stats?

    render inertia: 'Dashboard/Index', props: { stats: }
  end
end
