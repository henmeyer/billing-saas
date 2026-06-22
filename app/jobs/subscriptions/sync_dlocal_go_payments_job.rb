# frozen_string_literal: true

class Subscriptions::SyncDlocalGoPaymentsJob < ApplicationJob
  queue_as :billing

  # Rodar a cada 15–30 minutos via cron.
  # Itera account por account, consulta charges pendentes do dLocal Go na API.
  # Se o pagamento foi confirmado mas o webhook não chegou, processa aqui.
  def perform
    # Apenas accounts que têm gateway dlocal_go configurado
    account_ids = PaymentGateway.unscoped
                                .where(provider: "dlocal_go", active: true)
                                .pluck(:account_id)

    Account.where(id: account_ids).find_each do |account|
      ActsAsTenant.with_tenant(account) do
        sync_pending_charges
      rescue StandardError => e
        Rails.logger.error("[SyncDlocalGo] Erro na account #{account.id}: #{e.message}")
      end
    end
  end

  private

  def sync_pending_charges
    adapter = Gateways::DlocalGoAdapter.new

    Charge.pending
          .where(gateway: "dlocal_go")
          .where("created_at > ?", 7.days.ago)
          .includes(:customer, :subscription)
          .find_each do |charge|
      check_payment(charge, adapter)
    rescue StandardError => e
      Rails.logger.error(
        "[SyncDlocalGo] Erro ao verificar charge #{charge.id}: #{e.message}"
      )
    end
  end

  def check_payment(charge, adapter)
    result = adapter.get_payment(charge.gateway_charge_id)
    status = result["status"]&.upcase

    case status
    when "PAID", "COMPLETED", "APPROVED"
      confirm_payment(charge)
    when "REJECTED", "CANCELLED", "EXPIRED", "FAILED"
      fail_payment(charge)
    end
    # PENDING/AUTHORIZED → não faz nada, espera
  end

  def confirm_payment(charge)
    return if charge.paid?

    charge.update!(status: "paid", paid_at: Time.current)

    subscription = charge.subscription
    return unless subscription

    renew_subscription(subscription, charge) unless charge.charge_type_product?

    WebhookDispatchJob.perform_later(
      charge.customer,
      "payment.received",
      { amount_cents: charge.amount_cents, gateway: "dlocal_go", charge_id: charge.gateway_charge_id }
    )
  end

  def renew_subscription(subscription, charge)
    period_start = Time.current.beginning_of_day
    period_end   = case subscription.plan.billing_cycle
                   when "yearly" then 1.year.from_now.beginning_of_day
                   else 1.month.from_now.beginning_of_day
                   end

    ActiveRecord::Base.transaction do
      # 1. Sempre atualiza status para active e datas do período
      subscription.update!(
        status:               "active",
        current_period_start: period_start,
        current_period_end:   period_end
      )

      # 2. Cria período apenas se não existe (idempotente)
      existing_period = subscription.subscription_periods.find_by(period_start: period_start)
      return if existing_period

      new_period = subscription.subscription_periods.create!(
        period_start:        period_start,
        period_end:          period_end,
        amount_cents:        charge.amount_cents,
        base_amount_cents:   subscription.base_price_cents,
        extras_amount_cents: [charge.amount_cents - subscription.base_price_cents, 0].max
      )

      replicate_period_data(subscription, new_period)
    end

    WebhookDispatchJob.perform_later(
      subscription.customer,
      "subscription.renewed",
      { period_end: period_end }
    )
  end

  def fail_payment(charge)
    return if charge.status == "failed"

    charge.update!(status: "failed")

    subscription = charge.subscription
    return unless subscription

    subscription.update!(status: "past_due")

    WebhookDispatchJob.perform_later(
      charge.customer,
      "payment.failed",
      { gateway: "dlocal_go", charge_id: charge.gateway_charge_id }
    )
  end

  def replicate_period_data(subscription, new_period)
    previous = subscription.subscription_periods
                           .where.not(id: new_period.id)
                           .order(created_at: :desc)
                           .first
    return unless previous

    previous.subscription_period_credits.each do |spc|
      new_period.subscription_period_credits.create!(
        credit_type: spc.credit_type, quantity: spc.quantity,
        base: spc.base, extras: spc.extras, extra_packages: spc.extra_packages
      )
      new_period.credit_snapshots.create!(
        credit_type: spc.credit_type, used: 0,
        limit: spc.quantity, synced_at: Time.current
      )
    end

    previous.subscription_period_licenses.each do |spl|
      new_period.subscription_period_licenses.create!(
        license_type: spl.license_type, quantity: spl.quantity
      )
    end
  end
end
