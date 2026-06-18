class AddConvertedAtAndNullableGatewayToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :subscriptions, :converted_at, :datetime
    # Trial não tem gateway até a conversão em assinatura paga
    change_column_null :subscriptions, :gateway, true
  end
end
