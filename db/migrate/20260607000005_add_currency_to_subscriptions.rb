class AddCurrencyToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_reference :subscriptions, :currency, foreign_key: true, null: true
  end
end
