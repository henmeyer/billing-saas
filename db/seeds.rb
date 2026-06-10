puts "🌱 Iniciando seeds..."

# ── Conta principal ────────────────────────────────────────────────────────────
account = Account.find_by(slug: "nexloo-demo") || begin
  result = Accounts::CreateService.call(
    company_name:          "Nexloo Demo",
    name:                  "John Doe",
    email:                 "john@billing.com",
    password:              "password123",
    password_confirmation: "password123"
  )
  raise result.errors.join(", ") unless result.success?

  puts "  ✓ Conta criada: #{result.account.name}"
  result.account
end

ActsAsTenant.with_tenant(account) do
  # Atalhos para os tipos já criados pelo DefaultTypesService
  user_lic  = LicenseType.find_by!(key: "user_licenses")
  agent_lic = LicenseType.find_by!(key: "agent_licenses")

  coins      = CreditType.find_by!(key: "coins")
  ai_tokens  = CreditType.find_by!(key: "ai_tokens")
  sms        = CreditType.find_by!(key: "sms")

  # ── Moeda padrão ─────────────────────────────────────────────────────────────
  brl = Currency.find_or_create_by!(code: "BRL") do |c|
    c.name    = "Real Brasileiro"
    c.symbol  = "R$"
    c.default = true
    c.active  = true
  end

  # ── Usuário admin extra ──────────────────────────────────────────────────────
  unless User.exists?(email: "admin@billing.com")
    admin = User.create!(
      name:                  "Admin Demo",
      email:                 "admin@billing.com",
      password:              "password123",
      password_confirmation: "password123"
    )
    AccountUser.create!(account: account, user: admin, role: "admin")
    puts "  ✓ Usuário admin criado"
  end

  # ── Planos ───────────────────────────────────────────────────────────────────
  starter = Plan.find_or_create_by!(name: "Starter") do |p|
    p.billing_cycle = "monthly"
    p.pricing_model = "flat"
    p.trial_days    = 7
    p.active        = true
  end
  PlanPrice.find_or_create_by!(plan: starter, currency: brl) { |pp| pp.amount_cents = 9_900 }

  pro = Plan.find_or_create_by!(name: "Pro") do |p|
    p.billing_cycle = "monthly"
    p.pricing_model = "flat"
    p.trial_days    = 14
    p.active        = true
  end
  PlanPrice.find_or_create_by!(plan: pro, currency: brl) { |pp| pp.amount_cents = 29_900 }

  enterprise = Plan.find_or_create_by!(name: "Enterprise") do |p|
    p.billing_cycle = "monthly"
    p.pricing_model = "flat"
    p.trial_days    = 0
    p.active        = true
  end
  PlanPrice.find_or_create_by!(plan: enterprise, currency: brl) { |pp| pp.amount_cents = 99_900 }

  puts "  ✓ Planos criados: Starter / Pro / Enterprise"

  # Licenças por plano
  PlanLicense.find_or_create_by!(plan: starter,    license_type: user_lic)  { |pl| pl.quantity = 5  }
  PlanLicense.find_or_create_by!(plan: starter,    license_type: agent_lic) { |pl| pl.quantity = 1  }
  PlanLicense.find_or_create_by!(plan: pro,        license_type: user_lic)  { |pl| pl.quantity = 20 }
  PlanLicense.find_or_create_by!(plan: pro,        license_type: agent_lic) { |pl| pl.quantity = 5  }
  PlanLicense.find_or_create_by!(plan: enterprise, license_type: user_lic)  { |pl| pl.quantity = 0  } # 0 = ilimitado
  PlanLicense.find_or_create_by!(plan: enterprise, license_type: agent_lic) { |pl| pl.quantity = 0  }

  # Créditos por plano
  PlanCredit.find_or_create_by!(plan: starter,    credit_type: coins)     { |pc| pc.quantity = 1_000  }
  PlanCredit.find_or_create_by!(plan: starter,    credit_type: sms)       { |pc| pc.quantity = 100    }
  PlanCredit.find_or_create_by!(plan: pro,        credit_type: coins)     { |pc| pc.quantity = 5_000  }
  PlanCredit.find_or_create_by!(plan: pro,        credit_type: ai_tokens) { |pc| pc.quantity = 500    }
  PlanCredit.find_or_create_by!(plan: pro,        credit_type: sms)       { |pc| pc.quantity = 500    }
  PlanCredit.find_or_create_by!(plan: enterprise, credit_type: coins)     { |pc| pc.quantity = 20_000 }
  PlanCredit.find_or_create_by!(plan: enterprise, credit_type: ai_tokens) { |pc| pc.quantity = 5_000  }
  PlanCredit.find_or_create_by!(plan: enterprise, credit_type: sms)       { |pc| pc.quantity = 2_000  }

  puts "  ✓ Licenças e créditos dos planos configurados"

  # ── Gateway de pagamento (mock) ───────────────────────────────────────────────
  PaymentGateway.find_or_create_by!(provider: "stripe") do |gw|
    gw.api_key_enc = Rails.application.message_verifier(:gateway).generate("sk_test_demo")
    gw.active      = true
    gw.default     = true
  end

  # ── Clientes ─────────────────────────────────────────────────────────────────
  customers_data = [
    { name: "Empresa Alpha Ltda",  email: "contato@alpha.com.br",  external_id: "EXT001", status: "active",
plan: pro,        health: 95, gateway_sub: "sub_alpha_001"  },
    { name: "Empresa Beta S/A",    email: "ti@beta.com.br",        external_id: "EXT002", status: "active",
plan: pro,        health: 72, gateway_sub: "sub_beta_001"   },
    { name: "Empresa Gamma ME",    email: "admin@gamma.com.br",    external_id: "EXT003", status: "active",
plan: starter,    health: 45, gateway_sub: "sub_gamma_001"  },
    { name: "Empresa Delta Ltda",  email: "financeiro@delta.com",  external_id: "EXT004", status: "suspended",
plan: enterprise, health: 20, gateway_sub: "sub_delta_001"  },
    { name: "Empresa Épsilon Inc", email: "cto@epsilon.io",        external_id: "EXT005", status: "active",
plan: enterprise, health: 98, gateway_sub: "sub_epsilon_001" }
  ]

  customers_data.each do |data|
    customer = Customer.find_or_create_by!(external_id: data[:external_id]) do |c|
      c.name         = data[:name]
      c.email        = data[:email]
      c.status       = data[:status]
      c.health_score = data[:health]
    end

    # Assinatura
    sub = Subscription.find_or_create_by!(
      gateway:                 "stripe",
      gateway_subscription_id: data[:gateway_sub]
    ) do |s|
      s.customer             = customer
      s.plan                 = data[:plan]
      s.currency             = brl
      s.status               = data[:external_id] == "EXT003" ? "past_due" : "active"
      s.started_at           = 3.months.ago
      s.current_period_start = 1.day.ago.beginning_of_day
      s.current_period_end   = 29.days.from_now.beginning_of_day
    end

    # Período atual
    period = SubscriptionPeriod.find_or_create_by!(
      subscription: sub,
      period_start: sub.current_period_start
    ) { |p| p.period_end = sub.current_period_end }

    # Quantidades contratadas de créditos + snapshots
    data[:plan].plan_credits.includes(:credit_type).each do |pc|
      SubscriptionPeriodCredit.find_or_create_by!(
        subscription_period: period,
        credit_type:         pc.credit_type
      ) do |spc|
        spc.quantity       = pc.quantity
        spc.base           = pc.quantity
        spc.extras         = 0
        spc.extra_packages = 0
      end

      used = (pc.quantity * rand(0.1..0.85)).to_i
      CreditSnapshot.find_or_create_by!(
        subscription_period: period,
        credit_type:         pc.credit_type
      ) do |s|
        s.used      = used
        s.limit     = pc.quantity
        s.synced_at = Time.current
      end
    end

    # Quantidades contratadas de licenças
    data[:plan].plan_licenses.includes(:license_type).each do |pl|
      SubscriptionPeriodLicense.find_or_create_by!(
        subscription_period: period,
        license_type:        pl.license_type
      ) { |spl| spl.quantity = pl.quantity }
    end

    # Cobranças históricas (3 meses)
    3.times do |i|
      paid_at = (i + 1).months.ago
      Charge.find_or_create_by!(
        gateway:           "stripe",
        gateway_charge_id: "ch_#{data[:external_id].downcase}_#{i}"
      ) do |c|
        c.customer = customer
        c.subscription = sub
        c.amount_cents = data[:plan].price_for(brl)
        c.status      = "paid"
        c.paid_at     = paid_at
      end
    end
  end

  puts "  ✓ #{customers_data.size} clientes criados com assinaturas, períodos e cobranças"

  # Gamma em atraso (past_due)
  Subscription.find_by(gateway_subscription_id: "sub_gamma_001")
              &.update!(status: "past_due")

  # ── Integração de exemplo ─────────────────────────────────────────────────────
  unless Integration.exists?(name: "Sistema Externo Demo")
    Integration.create!(
      name:   "Sistema Externo Demo",
      url:    "https://httpbin.org/post",
      events: Integration::AVAILABLE_EVENTS,
      active: true
    )
    puts "  ✓ Integração de exemplo criada"
  end

  # ── API key de exemplo ────────────────────────────────────────────────────────
  unless account.api_keys.exists?(name: "Demo Key")
    _key, token = ApiKey.generate!(account: account, name: "Demo Key")
    puts "  ✓ API Key criada"
    puts "    Token (guarde agora): #{token}"
  end
end

puts ""
puts "✅ Seeds concluídos!"
puts ""
puts "  Login: john@billing.com / password123"
puts "  Admin: admin@billing.com   / password123"
puts "  Clientes: EXT001 ao EXT005"
