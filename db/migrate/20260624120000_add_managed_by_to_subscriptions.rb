class AddManagedByToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    # "gateway" = Asaas/Stripe controla a recorrência
    # "billing" = billing controla a recorrência (cria payments avulsos)
    add_column :subscriptions, :managed_by, :string,
               null: false, default: "gateway"

    # Todas as subscriptions existentes ficam como gateway-managed
    # (sem impacto — Asaas continua cobrando normalmente)
  end
end
