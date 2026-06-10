class AddPriceToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :subscriptions, :base_price_cents, :integer, null: false, default: 0
    add_column :subscriptions, :currency_code,    :string,  null: false, default: 'BRL'
  end
end
