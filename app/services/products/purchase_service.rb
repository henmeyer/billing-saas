class Products::PurchaseService
  Result = Struct.new(:success?, :errors)

  def self.call(**args) = new(**args).call

  def initialize(customer:, product:, notes: nil)
    @customer = customer
    @product  = product
    @notes    = notes
  end

  def call
    return Result.new(false, ["Produto inativo"]) unless @product.active?

    ActiveRecord::Base.transaction do
      if @product.product_type == "credit_pack" && @product.credit_type_id.present?
        period = @customer.current_period
        return Result.new(false, ["Cliente sem assinatura ativa"]) unless period

        snapshot = period.credit_snapshots.find_or_initialize_by(
          credit_type_id: @product.credit_type_id
        )

        new_limit = snapshot.limit.to_i + @product.credit_quantity
        snapshot.update!(
          limit:     new_limit,
          balance:   new_limit - snapshot.used.to_i,
          synced_at: Time.current
        )

        WebhookDispatchJob.perform_later(
          @customer, "credits.recharged",
          {
            credit_type: @product.credit_type.key,
            added:       @product.credit_quantity,
            new_balance: snapshot.balance
          }
        )
      end

      Result.new(true, [])
    end
  rescue => e
    Result.new(false, [e.message])
  end
end
