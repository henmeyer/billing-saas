class AddExtrasPricingToPlanCredits < ActiveRecord::Migration[7.1]
  def change
    add_column :plan_credits, :extra_unit_size, :integer, default: 0
    add_column :plan_credits, :extra_unit_price_cents, :integer, default: 0
    add_column :plan_credits, :allow_extras, :boolean, default: false
  end
end
