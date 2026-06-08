class RemovePriceCentsFromPlans < ActiveRecord::Migration[7.1]
  def change
    remove_column :plans, :price_cents, :integer
    remove_column :plans, :currency,    :string
  end
end
