class CreateCreditAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_alerts do |t|
      t.references :customer,    null: false, foreign_key: true
      t.references :credit_type, null: false, foreign_key: true
      t.integer  :threshold,     null: false
      t.datetime :period_start,  null: false
      t.timestamps
    end
  end
end
