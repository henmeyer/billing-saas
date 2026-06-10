class CreatePortalSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :portal_sessions do |t|
      t.references :customer,    null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.string  :token_digest,   null: false
      t.datetime :expires_at,    null: false
      t.datetime :accessed_at
      t.string  :ip_address
      t.timestamps
    end
    add_index :portal_sessions, :token_digest, unique: true
  end
end
