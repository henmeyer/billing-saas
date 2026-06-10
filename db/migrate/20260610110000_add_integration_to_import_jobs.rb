class AddIntegrationToImportJobs < ActiveRecord::Migration[7.1]
  def change
    add_reference :import_jobs, :integration, null: true, foreign_key: true
  end
end
