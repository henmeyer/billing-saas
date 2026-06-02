class DashboardController < ApplicationController
  def index
    @stats = Dashboard::StatsService.call(current_account)
  end
end
