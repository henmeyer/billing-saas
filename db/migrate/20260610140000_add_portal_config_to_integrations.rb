class AddPortalConfigToIntegrations < ActiveRecord::Migration[7.1]
  def change
    add_column :integrations, :portal_config, :jsonb, null: false, default: {
      'allow_plan_change'    => true,
      'allow_buy_products'   => true,
      'allow_adjust_extras'  => true,
      'show_invoice_history' => true,
      'allow_cancel'         => false
    }
    add_column :integrations, :portal_logo_url,     :string
    add_column :integrations, :portal_primary_color, :string, default: '#6366f1'
  end
end
