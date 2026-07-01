class Portal::CreateChargeService
  def self.call(customer:, product:, integration:, gateway:, quantity: 1)
    new(customer:, product:, integration:, gateway:, quantity:).call
  end

  def initialize(customer:, product:, integration:, gateway:, quantity: 1)
    @customer    = customer
    @product     = product
    @integration = integration
    @gateway     = gateway
    @quantity    = [quantity.to_i, 1].max
  end

  def call
    adapter = Gateways::Base.for(@gateway)

    currency = @customer.effective_currency
    price_cents = @product.calculate_price(@quantity, currency)

    result = adapter.create_charge(
      @customer,
      price_cents,
      description:    @product.name,
      currency:       currency&.code || "BRL",
      payment_method: "BANK_TRANSFER"
    )

    subscription = @customer.subscriptions
                            .active
                            .find_by(integration: @integration)

    charge = @customer.charges.create!(
      subscription:      subscription,
      gateway:           @gateway,
      gateway_charge_id: result["id"] || result[:id],
      amount_cents:      price_cents,
      status:            "pending",
      redirect_url:      result["invoiceUrl"] || result[:invoiceUrl],
      charge_data:       extract_charge_data(result),
      charge_type:       "product",
      due_date:          3.days.from_now
    )

    charge.charge_data["product_purchase"] = product_purchase_payload
    charge.save!

    charge
  end

  private

  # Dados consumidos por Charges::ApplyPaidChargeService quando o pagamento
  # for confirmado. total_credits = crédito por unidade × quantidade comprada.
  def product_purchase_payload
    {
      "product_id"      => @product.id,
      "product_type"    => @product.product_type,
      "credit_type_id"  => @product.credit_type_id,
      "credit_per_unit" => @product.credit_quantity.to_i,
      "quantity"        => @quantity,
      "total_credits"   => @product.credit_quantity.to_i * @quantity
    }
  end

  def extract_charge_data(result)
    {
      "pix_qr_code"    => result["pix_qr_code"] || result.dig("point_of_interaction", "qr_code"),
      "pix_copy_paste" => result["pix_copy_paste"] || result.dig("point_of_interaction", "qr_code_base64"),
      "boleto_url"     => result["boleto_url"] || result["ticket_url"],
      "boleto_barcode" => result["boleto_barcode"] || result["typeable_barcode"]
    }
  end
end
