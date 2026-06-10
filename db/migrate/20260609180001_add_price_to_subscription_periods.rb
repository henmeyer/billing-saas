class AddPriceToSubscriptionPeriods < ActiveRecord::Migration[7.1]
  def change
    add_column :subscription_periods, :amount_cents,        :integer, null: false, default: 0
    add_column :subscription_periods, :base_amount_cents,   :integer, null: false, default: 0
    add_column :subscription_periods, :extras_amount_cents, :integer, null: false, default: 0
  end
end
