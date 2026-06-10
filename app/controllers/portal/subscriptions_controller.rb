class Portal::SubscriptionsController < Portal::BaseController
  def update
    unless portal_config["allow_adjust_extras"]
      redirect_to portal_dashboard_path(token: portal_token),
                  alert: "Ajuste de extras não disponível."
      return
    end

    set_tenant!
    sub = current_subscription

    adapter = Gateways::Base.for(sub.gateway)

    extra_packages = params[:extra_packages]&.to_unsafe_h || {}

    base_price = sub.base_price_cents
    extras_total = 0

    sub.plan.plan_credits.where(allow_extras: true).each do |pc|
      n = (extra_packages[pc.credit_type_id.to_s] || 0).to_i
      next unless n > 0
      extras_total += pc.extra_unit_price_cents * n
    end

    new_amount = base_price + extras_total

    adapter.update_subscription(
      sub.gateway_subscription_id,
      sub.plan,
      amount_cents: new_amount
    )

    period = sub.current_period
    period.update!(
      amount_cents:        new_amount,
      extras_amount_cents: extras_total
    )

    sub.plan.plan_credits.where(allow_extras: true).each do |pc|
      n = (extra_packages[pc.credit_type_id.to_s] || 0).to_i
      spc = period.subscription_period_credits
                  .find_by(credit_type: pc.credit_type)
      next unless spc

      new_extras = pc.extra_unit_size * n
      new_total  = pc.quantity + new_extras

      spc.update!(
        quantity:       new_total,
        extras:         new_extras,
        extra_packages: n
      )

      snapshot = period.credit_snapshots.find_by(credit_type: pc.credit_type)
      snapshot&.update!(limit: new_total)
    end

    sub.update!(metadata: sub.metadata.merge("extra_packages" => extra_packages))

    redirect_to portal_dashboard_path(token: portal_token),
                notice: "Extras atualizados com sucesso."
  end

  def destroy
    unless portal_config["allow_cancel"]
      redirect_to portal_dashboard_path(token: portal_token),
                  alert: "Cancelamento não disponível."
      return
    end

    set_tenant!
    sub = current_subscription

    adapter = Gateways::Base.for(sub.gateway)
    adapter.cancel_subscription(sub.gateway_subscription_id)
    sub.update!(status: "cancelled", cancelled_at: Time.current)

    WebhookDispatchJob.perform_later(
      current_customer, "subscription.cancelled", {}
    )

    redirect_to portal_dashboard_path(token: portal_token),
                notice: "Assinatura cancelada."
  end
end
