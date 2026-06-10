class AddIdentitiesToImportJobs < ActiveRecord::Migration[7.1]
  def change
    add_column :import_jobs, :identities, :jsonb, null: false, default: {}
  end
end
