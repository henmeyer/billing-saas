class CreateFeatureTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :feature_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key,         null: false
      t.string :label,       null: false
      t.text   :description
      t.timestamps
    end
    add_index :feature_types, [:account_id, :key], unique: true
  end
end
