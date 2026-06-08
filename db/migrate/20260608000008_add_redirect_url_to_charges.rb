class AddRedirectUrlToCharges < ActiveRecord::Migration[7.1]
  def change
    add_column :charges, :redirect_url, :string
    add_column :charges, :charge_data,  :jsonb, null: false, default: {}
  end
end
