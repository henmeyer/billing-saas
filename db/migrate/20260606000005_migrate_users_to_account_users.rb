class MigrateUsersToAccountUsers < ActiveRecord::Migration[7.1]
  def up
    # Copia os vínculos user->account existentes para account_users
    execute <<-SQL
      INSERT INTO account_users (account_id, user_id, role, created_at, updated_at)
      SELECT account_id, id, role, NOW(), NOW()
      FROM users
      WHERE type IS NULL AND account_id IS NOT NULL
    SQL

    # Torna account_id opcional para permitir SuperAdmin sem account
    change_column_null :users, :account_id, true
  end

  def down
    change_column_null :users, :account_id, false
    execute "DELETE FROM account_users"
  end
end
