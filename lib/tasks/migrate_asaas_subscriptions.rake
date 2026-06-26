# frozen_string_literal: true

namespace :subscriptions do
  desc "Migra subscriptions do Asaas de gateway-managed para billing-managed"
  task migrate_asaas: :environment do
    # Uso: rails subscriptions:migrate_asaas
    # Ou:  rails subscriptions:migrate_asaas CUSTOMER_ID=123
    # Ou:  rails subscriptions:migrate_asaas BATCH=10
    # Ou:  rails subscriptions:migrate_asaas ACCOUNT_ID=5

    scope = Subscription.where(status: %w[active past_due])
                        .gateway_managed
                        .where(gateway: "asaas")
                        .includes(:customer, :plan)

    if ENV["ACCOUNT_ID"]
      scope = scope.joins(:customer).where(customers: { account_id: ENV["ACCOUNT_ID"] })
    end

    if ENV["CUSTOMER_ID"]
      scope = scope.where(customer_id: ENV["CUSTOMER_ID"])
    end

    if ENV["BATCH"]
      scope = scope.limit(ENV["BATCH"].to_i)
    end

    total   = scope.count
    success = 0
    errors  = 0

    puts "Migrando #{total} subscriptions Asaas de gateway-managed para billing-managed..."
    puts ""

    scope.find_each do |sub|
      ActsAsTenant.current_tenant = sub.customer.account

      begin
        # 1. Cancela subscription nativa no Asaas
        adapter = Gateways::AsaasAdapter.new
        adapter.cancel_subscription(sub.gateway_subscription_id)

        # 2. Marca como billing-managed
        sub.update!(
          managed_by: "billing",
          metadata:   sub.metadata.merge(
            "migrated_from_gateway" => true,
            "migrated_at"           => Time.current.iso8601,
            "original_asaas_sub_id" => sub.gateway_subscription_id
          )
        )

        success += 1
        puts "  [OK] Sub #{sub.id} | #{sub.customer.name} | Plano: #{sub.plan.name}"

      rescue => e
        errors += 1
        puts "  [ERRO] Sub #{sub.id} | #{sub.customer.name}: #{e.message}"
      end
    end

    puts ""
    puts "Resultado: #{success} migradas, #{errors} erros de #{total} total"
  end

  desc "Lista subscriptions Asaas pendentes de migração (gateway-managed)"
  task list_asaas_gateway: :environment do
    subs = Subscription.where(status: %w[active past_due])
                       .gateway_managed
                       .where(gateway: "asaas")
                       .includes(:customer, :plan)

    puts "#{subs.count} subscriptions gateway-managed no Asaas:"
    puts ""

    subs.find_each do |sub|
      renewal = sub.current_period_end&.strftime("%d/%m/%Y") || "N/A"
      puts "  ID: #{sub.id} | #{sub.customer.name} | " \
           "Plano: #{sub.plan.name} | Renova: #{renewal} | " \
           "Asaas: #{sub.gateway_subscription_id}"
    end

    puts ""
    puts "Total: #{subs.count}"
  end

  desc "Lista subscriptions Asaas já migradas (billing-managed)"
  task list_asaas_billing: :environment do
    subs = Subscription.where(status: %w[active past_due pending])
                       .billing_managed
                       .where(gateway: "asaas")
                       .includes(:customer, :plan)

    puts "#{subs.count} subscriptions billing-managed no Asaas:"
    puts ""

    subs.find_each do |sub|
      migrated = sub.metadata["migrated_at"] ? " (migrada em #{sub.metadata['migrated_at']})" : ""
      renewal  = sub.current_period_end&.strftime("%d/%m/%Y") || "N/A"
      puts "  ID: #{sub.id} | #{sub.customer.name} | " \
           "Plano: #{sub.plan.name} | Renova: #{renewal}#{migrated}"
    end

    puts ""
    puts "Total: #{subs.count}"
  end
end
