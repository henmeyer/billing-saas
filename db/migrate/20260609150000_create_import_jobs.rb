class CreateImportJobs < ActiveRecord::Migration[7.1]
  def change
    create_table :import_jobs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.string  :gateway,       null: false
      t.string  :status,        null: false, default: "pending"
      t.jsonb   :preview,       null: false, default: {}
      t.jsonb   :decisions,     null: false, default: {}
      t.jsonb   :result,        null: false, default: {}
      t.text    :error_message
      t.timestamps
    end
  end
end
