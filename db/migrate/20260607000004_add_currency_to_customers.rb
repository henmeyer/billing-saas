class AddCurrencyToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_reference :customers, :currency, foreign_key: true, null: true
  end
end
