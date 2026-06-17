class Portal::ProductsController < Portal::BaseController
  before_action :require_buy_products!

  def index
    set_tenant!
    products = Product.active
                      .where(product_type: "credit_pack")
                      .includes(:credit_type)

    render inertia: "Portal/Products/Index", props: {
      products:      products.map { |p| serialize(p) },
      portal_config: portal_config,
      branding:      branding
    }
  end

  def create
    set_tenant!
    product = Product.find(params[:product_id])

    charge = Portal::CreateChargeService.call(
      customer:    current_customer,
      product:     product,
      integration: current_integration,
      gateway:     current_subscription.gateway
    )

    if charge.redirect_url.present?
      redirect_to charge.redirect_url, allow_other_host: true
    else
      redirect_to portal_checkout_path(token: portal_token, charge_id: charge.id)
    end
  end

  private

  def require_buy_products!
    return if portal_config["allow_buy_products"]

    redirect_to portal_dashboard_path(token: portal_token),
                alert: "Compra de produtos não disponível."
  end

  def serialize(p)
    {
      id:              p.id,
      name:            p.name,
      description:     p.description,
      price_cents:     p.price_for(current_customer.effective_currency),
      credit_quantity: p.credit_quantity,
      credit_type:     p.credit_type&.label,
      credit_unit:     p.credit_type&.unit
    }
  end
end
