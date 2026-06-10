class Portal::CreateChargeService
  def self.call(customer:, product:, integration:, gateway:)
    new(customer:, product:, integration:, gateway:).call
  end

  def initialize(customer:, product:, integration:, gateway:)
    @customer    = customer
    @product     = product
    @integration = integration
    @gateway     = gateway
  end

  def call
    adapter = Gateways::Base.for(@gateway)

    currency = @customer.effective_currency
    price_cents = @product.price_for(currency)

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
      redirect_url:      result["redirect_url"] || result[:redirect_url],
      charge_data:       extract_charge_data(result),
      due_date:          3.days.from_now
    )

    charge.charge_data["pending_credit"] = {
      "credit_type_id" => @product.credit_type_id,
      "quantity"        => @product.credit_quantity
    }
    charge.save!

    charge
  end

  private

  def extract_charge_data(result)
    {
      "pix_qr_code"   => result["pix_qr_code"] || result.dig("point_of_interaction", "qr_code"),
      "pix_copy_paste" => result["pix_copy_paste"] || result.dig("point_of_interaction", "qr_code_base64"),
      "boleto_url"     => result["boleto_url"] || result["ticket_url"],
      "boleto_barcode" => result["boleto_barcode"] || result["typeable_barcode"]
    }
  end
end
