if defined?(Sidekiq)
  Sidekiq.configure_server do |config|
    schedule_file = Rails.root.join("config", "schedule.yml")

    if File.exist?(schedule_file)
      schedule = YAML.load_file(schedule_file)
      Sidekiq::Cron::Job.load_from_hash(schedule)
    end
  end
end
