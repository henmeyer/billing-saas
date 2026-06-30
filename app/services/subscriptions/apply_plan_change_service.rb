module Subscriptions
  # Aplica a troca de plano APÓS o pagamento da diferença (upgrade) ser
  # confirmado. Chamado pelo dispatcher Charges::ApplyPaidChargeService.
  #
  # Reusa Subscription#change_plan! (atualiza plano/base_price_cents, ajusta o
  # gateway e dispara plan.changed) e, em seguida, ajusta a alocação de
  # créditos do período atual para o novo plano (mantendo os extras já
  # comprados).
  class ApplyPlanChangeService
    Result = Struct.new(:success?, :errors)

    def self.call(charge:) = new(charge:).call

    def initialize(charge:)
      @charge = charge
      @data   = charge.charge_data["plan_change"] || {}
    end

    def call
      new_plan_id = @data["new_plan_id"]
      return Result.new(false, ["sem plano de destino"]) if new_plan_id.blank?

      subscription = @charge.subscription
      return Result.new(false, ["charge sem assinatura"]) unless subscription

      new_plan = Plan.find_by(id: new_plan_id)
      return Result.new(false, ["plano não encontrado"]) unless new_plan

      ActiveRecord::Base.transaction do
        subscription.change_plan!(new_plan, changed_by: @charge.customer, reason: "portal_upgrade")
        adjust_period_credits!(subscription, new_plan)
      end

      Result.new(true, [])
    rescue StandardError => e
      Result.new(false, [e.message])
    end

    private

    # Atualiza a base dos créditos do período atual para a alocação do novo
    # plano, preservando os extras já adquiridos (packs/extras).
    def adjust_period_credits!(subscription, new_plan)
      period = subscription.subscription_periods.current.last
      return unless period

      new_plan.plan_credits.includes(:credit_type).each do |pc|
        spc = period.subscription_period_credits.find_or_initialize_by(credit_type_id: pc.credit_type_id)
        spc.base     = pc.quantity
        spc.extras   = spc.extras.to_i
        spc.extra_packages = spc.extra_packages.to_i
        spc.quantity = spc.base + spc.extras
        spc.save!

        snapshot = period.credit_snapshots.find_or_initialize_by(credit_type_id: pc.credit_type_id)
        snapshot.used    ||= 0
        snapshot.limit     = spc.quantity
        snapshot.synced_at = Time.current
        snapshot.save!
      end
    end
  end
end
