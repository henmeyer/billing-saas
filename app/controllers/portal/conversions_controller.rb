class Portal::ConversionsController < Portal::BaseController
  def new
    set_tenant!
    sub = current_subscription

    unless sub&.trialing?
      redirect_to portal_redirect_path, alert: "Assinatura não está em teste."
      return
    end

    provider = resolve_provider(sub)

    unless provider
      redirect_to portal_redirect_path, alert: "Nenhum gateway de pagamento disponível."
      return
    end

    render inertia: "Portal/Conversion", props: {
      subscription:    serialize_subscription(sub),
      provider:        provider,
      payment_methods: Gateways::ResolverService.payment_methods_for(
        provider: provider, country: current_customer.country
      ),
      portal_config:   portal_config,
      branding:        branding
    }
  end

  def create
    set_tenant!
    sub = current_subscription

    unless sub&.trialing?
      redirect_to portal_redirect_path, alert: "Assinatura não está em teste."
      return
    end

    provider = resolve_provider(sub)

    unless provider
      redirect_to portal_redirect_path, alert: "Nenhum gateway de pagamento disponível."
      return
    end

    extra_packages = sub.metadata["extra_packages"] || {}
    pricing = Pricing::CalculateService.call(
      plan:           sub.plan,
      customer:       current_customer,
      currency:       sub.effective_currency,
      extra_packages: extra_packages
    )

    adapter = Gateways::Base.for(provider)
    adapter.create_customer(current_customer) unless current_customer.gateway_data[provider].present?

    result = adapter.create_charge(
      current_customer,
      pricing.amount_cents,
      currency:    sub.currency_code,
      country:     current_customer.country,
      description: "#{sub.plan.name} — Primeira mensalidade"
    )

    charge = current_customer.charges.create!(
      subscription:      sub,
      gateway:            provider,
      gateway_charge_id:  result["id"] || result[:id],
      amount_cents:       pricing.amount_cents,
      status:             "pending",
      redirect_url:       result["redirect_url"] || result[:redirect_url],
      charge_data:        result.to_h.stringify_keys.merge("conversion" => true)
    )

    # Salva o gateway na subscription para as futuras cobranças (renovação)
    sub.update!(gateway: provider)

    if charge.redirect_url.present?
      redirect_to charge.redirect_url, allow_other_host: true
    else
      redirect_to portal_checkout_path(token: portal_token, charge_id: charge.id)
    end
  end

  private

  def resolve_provider(sub)
    Gateways::ResolverService.call(
      account:       current_account,
      country:       current_customer.country,
      currency_code: sub.currency_code
    )
  end

  def serialize_subscription(s)
    {
      plan_name:            s.plan.name,
      base_price_cents:     s.base_price_cents,
      currency_code:        s.currency_code,
      trial_ends_at:        s.trial_ends_at&.strftime("%d/%m/%Y"),
      trial_days_remaining: s.trial_days_remaining
    }
  end
end
