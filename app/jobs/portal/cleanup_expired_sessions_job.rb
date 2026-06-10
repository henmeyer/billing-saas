class Portal::CleanupExpiredSessionsJob < ApplicationJob
  queue_as :low

  def perform
    deleted = PortalSession.cleanup_expired!
    Rails.logger.info "[Portal] Cleaned up #{deleted} expired sessions"
  end
end
