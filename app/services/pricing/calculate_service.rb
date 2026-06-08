class Pricing::CalculateService
  Result = Struct.new(:amount_cents, :quantity, :tier, :breakdown, :currency)

  def self.call(plan:, customer:, currency:)
    new(plan:, customer:, currency:).call
  end

  def initialize(plan:, customer:, currency:)
    @plan     = plan
    @customer = customer
    @currency = currency
  end

  def call
    quantity = @plan.current_quantity_for(@customer)
    amount   = @plan.calculate_price(quantity, @currency)

    Result.new(amount, quantity, current_tier(quantity), build_breakdown(quantity, amount), @currency)
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
end
