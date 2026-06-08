class AddPricingModelToPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :plans, :pricing_model, :string, null: false, default: "flat"

    add_reference :plans, :pricing_license_type,
                  foreign_key: { to_table: :license_types }, null: true
    add_reference :plans, :pricing_credit_type,
                  foreign_key: { to_table: :credit_types }, null: true
  end
end
