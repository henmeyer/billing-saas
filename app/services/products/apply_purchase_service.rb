module Products
  # Aplica os efeitos de uma charge de produto JÁ PAGA, a partir dos dados
  # gravados em charge_data["product_purchase"] pelo Portal::CreateChargeService.
  #
  # credit_pack  → crédito recorrente: incrementa o período atual (extras) e
  #                registra o pack em subscription.metadata["product_packs"]
  #                para ser cobrado/renovado a cada ciclo.
  # one_time     → crédito avulso: incrementa apenas o limite do snapshot do
  #                período atual (não replica na renovação). Sem credit_type,
  #                é apenas uma cobrança avulsa sem efeito de crédito.
  class ApplyPurchaseService
    Result = Struct.new(:success?, :errors)

    def self.call(charge:) = new(charge:).call

    def initialize(charge:)
      @charge = charge
      @data   = charge.charge_data["product_purchase"] || {}
    end

    def call
      return Result.new(false, ["sem dados de compra"]) if @data.blank?

      credit_type_id = @data["credit_type_id"]
      total_credits  = @data["total_credits"].to_i

      # one_time sem crédito (ou crédito zerado): nada a aplicar.
      return Result.new(true, []) if credit_type_id.blank? || total_credits <= 0

      subscription = @charge.subscription
      period       = subscription&.subscription_periods&.current&.last
      return Result.new(false, ["sem período ativo"]) unless period

      ActiveRecord::Base.transaction do
        bump_snapshot!(period, credit_type_id, total_credits)

        if @data["product_type"] == "credit_pack"
          apply_recurring_pack!(subscription, period, credit_type_id, total_credits)
        end
      end

      dispatch_recharge_webhook(credit_type_id, total_credits)

      Result.new(true, [])
    rescue StandardError => e
      Result.new(false, [e.message])
    end

    private

    # Aumenta o limite disponível no período atual (vale para os dois tipos).
    def bump_snapshot!(period, credit_type_id, total_credits)
      snapshot = period.credit_snapshots.find_or_initialize_by(credit_type_id: credit_type_id)
      snapshot.used      ||= 0
      snapshot.limit       = snapshot.limit.to_i + total_credits
      snapshot.synced_at   = Time.current
      snapshot.save! # balance/usage_percent recalculados no before_save
    end

    # credit_pack: registra como extras recorrentes (replicados na renovação)
    # e soma ao valor de extras do período + metadata para recobrança.
    def apply_recurring_pack!(subscription, period, credit_type_id, total_credits)
      quantity = @data["quantity"].to_i

      spc = period.subscription_period_credits.find_or_initialize_by(credit_type_id: credit_type_id)
      spc.base           = spc.base.to_i
      spc.extras         = spc.extras.to_i + total_credits
      spc.extra_packages = spc.extra_packages.to_i + quantity
      spc.quantity       = spc.quantity.to_i + total_credits
      spc.save!

      period.update!(
        extras_amount_cents: period.extras_amount_cents.to_i + @charge.amount_cents
      )

      register_product_pack!(subscription, quantity)
    end

    def register_product_pack!(subscription, quantity)
      packs = subscription.metadata["product_packs"] || {}
      key   = @data["product_id"].to_s
      packs[key] = packs[key].to_i + quantity
      subscription.update!(metadata: subscription.metadata.merge("product_packs" => packs))
    end

    def dispatch_recharge_webhook(credit_type_id, total_credits)
      credit_type = CreditType.find_by(id: credit_type_id)
      WebhookDispatchJob.perform_later(
        @charge.customer,
        "credits.recharged",
        { credit_type: credit_type&.key, added: total_credits }
      )
    end
  end
end
