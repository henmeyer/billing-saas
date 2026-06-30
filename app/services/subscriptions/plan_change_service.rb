module Subscriptions
  # Orquestra a troca de plano iniciada pelo cliente no portal.
  #
  # Upgrade (plano novo mais caro): cobra a diferença proporcional aos dias
  # restantes do ciclo via charge avulsa (charge_type "plan_change") com
  # checkout. O plano e os créditos só são aplicados após o pagamento
  # confirmar (Subscriptions::ApplyPlanChangeService).
  #
  # Downgrade (plano novo mais barato ou igual): agenda a troca para o fim do
  # período atual (sem reembolso) em subscription.metadata["scheduled_plan_change"].
  #
  # Fluxo uniforme para todos os gateways.
  class PlanChangeService
    Result = Struct.new(:type, :charge, :scheduled_plan_id, :prorated_cents, keyword_init: true)

    def self.call(subscription:, new_plan:, changed_by:)
      new(subscription:, new_plan:, changed_by:).call
    end

    def initialize(subscription:, new_plan:, changed_by:)
      @subscription = subscription
      @new_plan     = new_plan
      @changed_by   = changed_by
    end

    def call
      currency     = @subscription.effective_currency
      new_base     = @new_plan.price_for(currency)
      current_base = @subscription.base_price_cents.to_i

      if new_base > current_base
        upgrade(currency, new_base, current_base)
      else
        downgrade
      end
    end

    private

    def upgrade(currency, new_base, current_base)
      prorated = prorated_difference(new_base, current_base)

      # Sem dias restantes (ou diferença irrisória): aplica no próximo ciclo.
      return schedule! if prorated <= 0

      adapter = Gateways::Base.for(@subscription.gateway)
      result  = adapter.create_charge(
        @subscription.customer,
        prorated,
        description: "Upgrade para #{@new_plan.name}",
        currency:    currency&.code || "BRL"
      )

      charge = @subscription.charges.create!(
        customer:          @subscription.customer,
        gateway:           @subscription.gateway,
        gateway_charge_id: result["id"] || result[:id],
        amount_cents:      prorated,
        status:            "pending",
        redirect_url:      result["redirect_url"] || result[:redirect_url],
        charge_type:       "plan_change",
        due_date:          3.days.from_now,
        charge_data:       charge_data(result, new_base, prorated)
      )

      Result.new(type: :upgrade, charge: charge, prorated_cents: prorated)
    end

    def downgrade
      schedule!
    end

    def schedule!
      @subscription.update!(
        metadata: @subscription.metadata.merge(
          "scheduled_plan_change" => {
            "plan_id"      => @new_plan.id,
            "effective_at" => @subscription.current_period_end&.iso8601
          }
        )
      )

      Result.new(
        type:              new_base_greater? ? :upgrade_scheduled : :downgrade,
        scheduled_plan_id: @new_plan.id
      )
    end

    def new_base_greater?
      @new_plan.price_for(@subscription.effective_currency) > @subscription.base_price_cents.to_i
    end

    # Diferença proporcional aos dias restantes do período atual.
    def prorated_difference(new_base, current_base)
      diff = new_base - current_base
      return 0 if diff <= 0

      period_start = @subscription.current_period_start&.to_date
      period_end   = @subscription.current_period_end&.to_date
      return diff if period_start.nil? || period_end.nil?

      total_days = (period_end - period_start).to_i
      return diff if total_days <= 0

      remaining = (period_end - Date.current).to_i.clamp(0, total_days)
      ((diff * remaining) / total_days.to_f).round
    end

    def charge_data(result, new_base, prorated)
      {
        "plan_change" => {
          "new_plan_id"      => @new_plan.id,
          "previous_plan_id" => @subscription.plan_id,
          "new_base_cents"   => new_base,
          "prorated_cents"   => prorated,
          "changed_by_id"    => @changed_by&.id
        },
        "pix_qr_code"    => result["pix_qr_code"] || result.dig("point_of_interaction", "qr_code"),
        "pix_copy_paste" => result["pix_copy_paste"] || result.dig("point_of_interaction", "qr_code_base64"),
        "boleto_url"     => result["boleto_url"] || result["ticket_url"]
      }
    end
  end
end
