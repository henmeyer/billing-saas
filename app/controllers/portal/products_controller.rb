class Portal::ProductsController < Portal::BaseController
  before_action :require_buy_products!

  def index
    set_tenant!
    products = Product.active
                      .where(product_type: %w[credit_pack one_time])
                      .joins(:product_integrations)
                      .where(product_integrations: { integration_id: current_integration.id })
                      .includes(:credit_type, :product_pricing_tiers)
                      .distinct

    render inertia: "Portal/Products/Index", props: {
      products:      products.map { |p| serialize(p) },
      portal_config: portal_config,
      branding:      branding
    }
  end

  def create
    set_tenant!
    product  = Product.find(params[:product_id])
    quantity = sanitized_quantity

    charge = Portal::CreateChargeService.call(
      customer:    current_customer,
      product:     product,
      integration: current_integration,
      gateway:     current_subscription.gateway,
      quantity:    quantity
    )

    payment_url = if charge.redirect_url.present?
                    charge.redirect_url
                  else
                    portal_checkout_url(token: portal_token, charge_id: charge.id)
                  end

    render json: { payment_url: }
  rescue Gateways::Base::GatewayError
    render json:   { error: "Não foi possível processar a compra. Tente novamente ou entre em contato com o suporte." },
           status: :unprocessable_entity
  end

  private

  # Garante quantidade inteira >= 1 (default 1).
  def sanitized_quantity
    [params[:quantity].to_i, 1].max
  end

  def require_buy_products!
    return if portal_config["allow_buy_products"]

    redirect_to portal_dashboard_path(token: portal_token),
                alert: "Compra de produtos não disponível."
  end

  def serialize(product)
    currency = current_customer.effective_currency
    {
      id:              product.id,
      name:            product.name,
      description:     product.description,
      product_type:    product.product_type,
      pricing_model:   product.pricing_model,
      recurring:       product.credit_pack?,
      grants_credit:   product.grants_credit?,
      price_cents:     product.price_for(currency),
      credit_quantity: product.credit_quantity,
      credit_type:     product.credit_type&.label,
      credit_unit:     product.credit_type&.unit,
      pricing_tiers:   product.product_pricing_tiers
                              .where(currency: currency)
                              .ordered
                              .map do |t|
                                { from_unit: t.from_unit, to_unit: t.to_unit, unit_amount_cents: t.unit_amount_cents }
                              end
    }
  end
end
