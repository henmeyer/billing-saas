class Pricing::CalculateService
  Result = Struct.new(
    :amount_cents,
    :quantity,
    :tier,
    :breakdown,
    :currency,
    :extras_breakdown,
    keyword_init: true
  )

  def self.call(plan:, customer:, currency:, extra_packages: {})
    new(plan:, customer:, currency:, extra_packages:).call
  end

  def initialize(plan:, customer:, currency:, extra_packages: {})
    @plan           = plan
    @customer       = customer
    @currency       = currency
    @extra_packages = extra_packages
  end

  def call
    quantity    = @plan.current_quantity_for(@customer)
    base_amount = @plan.calculate_price(quantity, @currency)
    extras      = calculate_extras

    Result.new(
      amount_cents:     base_amount + extras[:total_cents],
      quantity:         quantity,
      tier:             current_tier(quantity),
      breakdown:        build_breakdown(quantity, base_amount),
      currency:         @currency,
      extras_breakdown: extras[:items]
    )
  end

  private

  def current_tier(quantity)
    return nil unless @plan.pricing_model == "volume"

    @plan.tier_for(quantity, @currency)
  end

  def build_breakdown(quantity, amount)
    case @plan.pricing_model
    when "flat"
      { type: "flat", amount_cents: amount }
    when "per_unit"
      {
        type:              "per_unit",
        quantity:          quantity,
        unit_amount_cents: @plan.unit_price_for(@currency),
        total_cents:       amount,
        metric:            @plan.pricing_metric_label
      }
    when "volume"
      tier = current_tier(quantity)
      {
        type:              "volume",
        quantity:          quantity,
        tier_label:        tier&.label,
        unit_amount_cents: tier&.unit_amount_cents,
        total_cents:       amount,
        metric:            @plan.pricing_metric_label
      }
    end
  end

  def calculate_extras
    items       = []
    total_cents = 0

    @plan.plan_credits.where(allow_extras: true).each do |pc|
      n_packages = @extra_packages[pc.credit_type_id.to_s].to_i
      n_packages = @extra_packages[pc.credit_type_id].to_i if n_packages == 0
      next if n_packages <= 0

      cost = pc.extras_cost(n_packages)
      total_cents += cost

      items << {
        credit_type_id:    pc.credit_type_id,
        credit_type_key:   pc.credit_type.key,
        credit_type_label: pc.credit_type.label,
        base_quantity:     pc.quantity,
        extra_packages:    n_packages,
        extra_unit_size:   pc.extra_unit_size,
        extra_quantity:    pc.extras_quantity(n_packages),
        total_quantity:    pc.total_quantity(n_packages),
        cost_cents:        cost
      }
    end

    { items:, total_cents: }
  end
end
