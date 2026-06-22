class AddChargeTypeToCharges < ActiveRecord::Migration[7.1]
  def up
    add_column :charges, :charge_type, :string

    execute <<~SQL.squish
      UPDATE charges
      SET charge_type = CASE
        WHEN charge_data ? 'pending_credit' OR charge_data ? 'credit_type_id' THEN 'product'
        WHEN charge_data ->> 'renewal' = 'true' THEN 'renewal'
        ELSE 'new_subscription'
      END
    SQL

    change_column_null :charges, :charge_type, false
    change_column_default :charges, :charge_type, "new_subscription"
  end

  def down
    remove_column :charges, :charge_type
  end
end
