class AddCountryToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :country, :string, default: "BR", null: false
  end
end
