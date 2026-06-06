class DashboardController < ApplicationController
  def index
    stats = Dashboard::StatsService.call(current_account)
    render inertia: 'Dashboard/Index', props: { stats: }
  end
end
