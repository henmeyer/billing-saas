class AddDlocalToPaymentGateways < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_gateways, :gateway_data, :jsonb, null: false, default: {}
  end
end
