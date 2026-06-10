namespace :portal do
  desc "Remove portal sessions expiradas"
  task cleanup_sessions: :environment do
    deleted = PortalSession.cleanup_expired!
    puts "#{deleted} portal sessions expiradas removidas."
  end
end
