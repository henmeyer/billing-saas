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
      password_confirmation: "password123",
      type: "SuperAdmin"
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

  # ── Planos Nexloo (baseados na oferta real) ───────────────────────────────────

  # Tipos de licença adicionais
  whatsapp_lic = LicenseType.find_or_create_by!(key: "whatsapp_connections") do |lt|
    lt.label = "Conexões de WhatsApp"
    lt.unit  = "conexão"
  end
  email_lic = LicenseType.find_or_create_by!(key: "email_accounts") do |lt|
    lt.label = "Contas de E-mail"
    lt.unit  = "conta"
  end
  telegram_lic = LicenseType.find_or_create_by!(key: "telegram_connections") do |lt|
    lt.label = "Conexões de Telegram"
    lt.unit  = "conexão"
  end

  # Tipos de crédito adicionais
  conversas = CreditType.find_or_create_by!(key: "conversations") do |ct|
    ct.label       = "Conversas"
    ct.unit        = "conversa"
    ct.reset_cycle = "billing_cycle"
  end
  disparos = CreditType.find_or_create_by!(key: "whatsapp_broadcasts") do |ct|
    ct.label       = "Disparos de WhatsApp"
    ct.unit        = "disparo"
    ct.reset_cycle = "billing_cycle"
  end

  # Features adicionais
  ft_ai_agent  = FeatureType.find_or_create_by!(key: "ai_agent")         { |ft| ft.label = "Agente de IA" }
  ft_typebot   = FeatureType.find_or_create_by!(key: "typebot_flows")    { |ft| ft.label = "Typebot / Fluxos" }
  ft_facebook  = FeatureType.find_or_create_by!(key: "facebook_instagram") { |ft| ft.label = "Facebook / Instagram" }
  ft_tiktok    = FeatureType.find_or_create_by!(key: "tiktok_connection") { |ft| ft.label = "Conexão de TikTok" }
  ft_crm       = FeatureType.find_or_create_by!(key: "crm_kanban")       { |ft| ft.label = "CRM Kanban" }

  # ── Plano Start ──────────────────────────────────────────────────────────────
  plan_start = Plan.find_or_create_by!(name: "Start") do |p|
    p.billing_cycle = "monthly"
    p.pricing_model = "flat"
    p.trial_days    = 7
    p.active        = true
    p.description   = "Para quem deseja organizar o atendimento humano."
  end
  PlanPrice.find_or_create_by!(plan: plan_start, currency: brl) { |pp| pp.amount_cents = 14_900 }

  # ── Plano Plantonista ────────────────────────────────────────────────────────
  plan_plantonista = Plan.find_or_create_by!(name: "Plantonista") do |p|
    p.billing_cycle = "monthly"
    p.pricing_model = "flat"
    p.trial_days    = 7
    p.active        = true
    p.description   = "Para quem deseja automatizar o atendimento."
  end
  PlanPrice.find_or_create_by!(plan: plan_plantonista, currency: brl) { |pp| pp.amount_cents = 34_900 }

  # ── Plano Pro+ ──────────────────────────────────────────────────────────────
  plan_pro_plus = Plan.find_or_create_by!(name: "Pro+") do |p|
    p.billing_cycle = "monthly"
    p.pricing_model = "flat"
    p.trial_days    = 7
    p.active        = true
    p.description   = "Para quem deseja automatizar e escalar atendimentos."
  end
  PlanPrice.find_or_create_by!(plan: plan_pro_plus, currency: brl) { |pp| pp.amount_cents = 59_900 }

  puts "  ✓ Planos Nexloo criados: Start / Plantonista / Pro+"

  # Licenças — ilimitadas (0) em todos os planos
  [plan_start, plan_plantonista, plan_pro_plus].each do |plan|
    PlanLicense.find_or_create_by!(plan: plan, license_type: whatsapp_lic) { |pl| pl.quantity = 0 }
    PlanLicense.find_or_create_by!(plan: plan, license_type: user_lic)     { |pl| pl.quantity = 0 }
    PlanLicense.find_or_create_by!(plan: plan, license_type: email_lic)    { |pl| pl.quantity = 0 }
    PlanLicense.find_or_create_by!(plan: plan, license_type: telegram_lic) { |pl| pl.quantity = 0 }
  end

  # Créditos — Conversas (com extras: R$ 89,90/1000)
  PlanCredit.find_or_create_by!(plan: plan_start, credit_type: conversas) do |pc|
    pc.quantity               = 1_000
    pc.allow_extras           = true
    pc.extra_unit_size        = 1_000
    pc.extra_unit_price_cents = 8_990
  end
  PlanCredit.find_or_create_by!(plan: plan_plantonista, credit_type: conversas) do |pc|
    pc.quantity               = 2_000
    pc.allow_extras           = true
    pc.extra_unit_size        = 1_000
    pc.extra_unit_price_cents = 8_990
  end
  PlanCredit.find_or_create_by!(plan: plan_pro_plus, credit_type: conversas) do |pc|
    pc.quantity               = 6_000
    pc.allow_extras           = true
    pc.extra_unit_size        = 1_000
    pc.extra_unit_price_cents = 8_990
  end

  # Créditos — Disparos de WhatsApp (com extras: R$ 49,90/1000)
  # Start não inclui disparos
  PlanCredit.find_or_create_by!(plan: plan_plantonista, credit_type: disparos) do |pc|
    pc.quantity               = 500
    pc.allow_extras           = true
    pc.extra_unit_size        = 1_000
    pc.extra_unit_price_cents = 4_990
  end
  PlanCredit.find_or_create_by!(plan: plan_pro_plus, credit_type: disparos) do |pc|
    pc.quantity               = 1_000
    pc.allow_extras           = true
    pc.extra_unit_size        = 1_000
    pc.extra_unit_price_cents = 4_990
  end

  # Features por plano
  # Start: CRM sim, IA não, Typebot não, Facebook não, TikTok não
  PlanFeature.find_or_create_by!(plan: plan_start, feature_type: ft_crm)      { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_start, feature_type: ft_ai_agent) { |pf| pf.enabled = false }
  PlanFeature.find_or_create_by!(plan: plan_start, feature_type: ft_typebot)  { |pf| pf.enabled = false }
  PlanFeature.find_or_create_by!(plan: plan_start, feature_type: ft_facebook) { |pf| pf.enabled = false }
  PlanFeature.find_or_create_by!(plan: plan_start, feature_type: ft_tiktok)   { |pf| pf.enabled = false }

  # Plantonista: CRM sim, IA sim, Typebot sim, Facebook sim, TikTok não
  PlanFeature.find_or_create_by!(plan: plan_plantonista, feature_type: ft_crm)      { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_plantonista, feature_type: ft_ai_agent) { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_plantonista, feature_type: ft_typebot)  { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_plantonista, feature_type: ft_facebook) { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_plantonista, feature_type: ft_tiktok)   { |pf| pf.enabled = false }

  # Pro+: tudo habilitado
  PlanFeature.find_or_create_by!(plan: plan_pro_plus, feature_type: ft_crm)      { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_pro_plus, feature_type: ft_ai_agent) { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_pro_plus, feature_type: ft_typebot)  { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_pro_plus, feature_type: ft_facebook) { |pf| pf.enabled = true }
  PlanFeature.find_or_create_by!(plan: plan_pro_plus, feature_type: ft_tiktok)   { |pf| pf.enabled = true }

  # Vincular planos Nexloo à integração (feito junto com os outros após integração ser criada)

  puts "  ✓ Licenças, créditos e features dos planos Nexloo configurados"

  # ── Gateway de pagamento (mock) ───────────────────────────────────────────────
  PaymentGateway.find_or_create_by!(provider: "stripe") do |gw|
    gw.api_key_enc = Rails.application.message_verifier(:gateway).generate("sk_test_demo")
    gw.active      = true
    gw.default     = true
  end

  # ── Integração (criada antes dos clientes para vincular assinaturas) ──────────
  integration = Integration.find_or_create_by!(name: "Sistema Externo Demo") do |i|
    i.url    = "https://httpbin.org/post"
    i.events = Integration::AVAILABLE_EVENTS
    i.active = true
  end
  puts "  ✓ Integração criada: #{integration.name}"

  # Vincular planos à integração via plan_integrations
  [starter, pro, enterprise, plan_start, plan_plantonista, plan_pro_plus].each do |plan|
    PlanIntegration.find_or_create_by!(plan: plan, integration: integration)
  end
  puts "  ✓ Planos vinculados à integração"

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
    customer = Customer.find_or_create_by!(email: data[:email]) do |c|
      c.name         = data[:name]
      c.status       = data[:status]
      c.health_score = data[:health]
    end

    # Vincular identidade externa (external_id) via customer_identities
    customer.set_identity!(integration: integration, external_id: data[:external_id])

    # Assinatura
    sub = Subscription.find_or_create_by!(
      gateway:                 "stripe",
      gateway_subscription_id: data[:gateway_sub]
    ) do |s|
      s.customer             = customer
      s.plan                 = data[:plan]
      s.integration          = integration
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
