class Portal::SubscriptionsController < Portal::BaseController
  def update
    unless portal_config["allow_adjust_extras"]
      redirect_to portal_dashboard_path(token: portal_token),
                  alert: "Ajuste de extras não disponível."
      return
    end

    set_tenant!
    sub = current_subscription

    extra_packages = params[:extra_packages]&.to_unsafe_h || {}
    period         = sub.current_period

    if period
      violation = sub.plan.plan_credits.where(allow_extras: true).includes(:credit_type).find do |pc|
        n         = (extra_packages[pc.credit_type_id.to_s] || 0).to_i
        new_total = pc.quantity + (pc.extra_unit_size * n)
        snapshot  = period.credit_snapshots.find_by(credit_type: pc.credit_type)
        snapshot && snapshot.used > new_total
      end

      if violation
        pc       = violation
        n        = (extra_packages[pc.credit_type_id.to_s] || 0).to_i
        new_total = pc.quantity + (pc.extra_unit_size * n)
        snapshot  = period.credit_snapshots.find_by(credit_type: pc.credit_type)
        redirect_to portal_dashboard_path(token: portal_token),
                    alert: "Não é possível reduzir #{pc.credit_type.label}: " \
                           "você já utilizou #{snapshot.used} #{pc.credit_type.unit}s " \
                           "neste período (mínimo seria #{snapshot.used})."
        return
      end
    end

    base_price   = sub.base_price_cents
    extras_total = 0

    sub.plan.plan_credits.where(allow_extras: true).each do |pc|
      n = (extra_packages[pc.credit_type_id.to_s] || 0).to_i
      extras_total += pc.extra_unit_price_cents * n if n.positive?
    end

    new_amount = base_price + extras_total

    if sub.gateway_managed?
      adapter = Gateways::Base.for(sub.gateway)
      adapter.update_subscription(sub.gateway_subscription_id, sub.plan, amount_cents: new_amount)
    end

    period&.update!(
      amount_cents:        new_amount,
      extras_amount_cents: extras_total
    )

    if period
      sub.plan.plan_credits.where(allow_extras: true).each do |pc|
        n   = (extra_packages[pc.credit_type_id.to_s] || 0).to_i
        spc = period.subscription_period_credits.find_by(credit_type: pc.credit_type)
        next unless spc

        new_extras = pc.extra_unit_size * n
        new_total  = pc.quantity + new_extras

        spc.update!(quantity: new_total, extras: new_extras, extra_packages: n)

        period.credit_snapshots.find_by(credit_type: pc.credit_type)&.update!(limit: new_total)
      end
    end

    sub.update!(metadata: sub.metadata.merge("extra_packages" => extra_packages))

    WebhookDispatchJob.perform_later(current_customer, "subscription.updated", {})

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

    if sub.gateway_managed?
      adapter = Gateways::Base.for(sub.gateway)
      adapter.cancel_subscription(sub.gateway_subscription_id)
    end

    sub.update!(status: "cancelled", cancelled_at: Time.current)

    WebhookDispatchJob.perform_later(current_customer, "subscription.cancelled", {})

    redirect_to portal_dashboard_path(token: portal_token),
                notice: "Assinatura cancelada."
  end
end
