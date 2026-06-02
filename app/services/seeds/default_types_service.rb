class Seeds::DefaultTypesService
  def self.call(account)
    ActsAsTenant.with_tenant(account) do
      LicenseType.create!([
                            { key: "user_licenses", label: "Usuários", unit: "usuário" },
                            { key: "agent_licenses",     label: "Agentes",    unit: "agente" },
                            { key: "workspace_licenses", label: "Workspaces", unit: "workspace" }
                          ])

      CreditType.create!([
                           { key: "coins", label: "Coins", unit: "coin", reset_cycle: "billing_cycle" },
                           { key: "ai_tokens",  label: "Tokens IA", unit: "token",    reset_cycle: "billing_cycle" },
                           { key: "sms",        label: "SMS",       unit: "mensagem", reset_cycle: "billing_cycle" },
                           { key: "executions", label: "Execuções", unit: "execução", reset_cycle: "billing_cycle" }
                         ])
    end
  end
end
