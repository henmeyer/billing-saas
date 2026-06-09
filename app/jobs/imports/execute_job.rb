class Imports::ExecuteJob < ApplicationJob
  queue_as :default

  def perform(import_job_id)
    import_job = ActsAsTenant.without_tenant { ImportJob.find(import_job_id) }
    ActsAsTenant.current_tenant = import_job.account
    Imports::ExecuteService.call(import_job)
  end
end
