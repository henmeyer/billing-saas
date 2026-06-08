class AddCurrencyToCharges < ActiveRecord::Migration[7.1]
  def change
    add_reference :charges, :currency, foreign_key: true, null: true
    remove_column :charges, :currency, :string
  end
end
