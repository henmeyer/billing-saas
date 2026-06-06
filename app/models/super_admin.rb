class SuperAdmin < User
  # STI — Rails salva type: "SuperAdmin" na tabela users
  # Não pertence a nenhuma account específica
  # Pode acessar qualquer account via ActsAsTenant.with_tenant(account)

  def superadmin? = true
end
