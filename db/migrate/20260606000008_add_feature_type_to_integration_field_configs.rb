class AddFeatureTypeToIntegrationFieldConfigs < ActiveRecord::Migration[7.1]
  def change
    add_reference :integration_field_configs, :feature_type,
                  foreign_key: true, null: true
  end
end
