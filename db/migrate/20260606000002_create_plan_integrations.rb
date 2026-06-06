class CreatePlanIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :plan_integrations do |t|
      t.references :plan,        null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.timestamps
    end

    add_index :plan_integrations, [:plan_id, :integration_id], unique: true
  end
end
