class SuperAdmin < User
  # STI — Rails salva type: "SuperAdmin" na tabela users
  # Pode ter account_users normalmente (colaborador de contas)
  # A diferença é: tem acesso ao painel admin e pode impersonar

  def superadmin? = true
  def admin?      = true

  def needs_account_selection?
    accounts.empty?
  end
end
