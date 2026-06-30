module Charges
  # Dispatcher acionado quando uma charge é confirmada como paga.
  # Roteia para o serviço específico conforme o charge_type e garante
  # idempotência (não aplica os efeitos duas vezes), marcando applied_at
  # em charge_data.
  class ApplyPaidChargeService
    def self.call(charge:) = new(charge:).call

    def initialize(charge:)
      @charge = charge
    end

    def call
      return :not_paid        unless @charge.paid?
      return :already_applied if applied?

      case @charge.charge_type
      when "product"
        Products::ApplyPurchaseService.call(charge: @charge)
      when "plan_change"
        Subscriptions::ApplyPlanChangeService.call(charge: @charge)
      else
        return :noop
      end

      mark_applied!
      :applied
    end

    private

    def applied?
      @charge.charge_data["applied_at"].present?
    end

    def mark_applied!
      @charge.charge_data["applied_at"] = Time.current.iso8601
      @charge.save!
    end
  end
end
