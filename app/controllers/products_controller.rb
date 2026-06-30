class ProductsController < ApplicationController
  before_action :set_product, only: [:edit, :update, :destroy]

  def index
    products = policy_scope(Product).includes(:credit_type, product_prices: :currency).order(name: :asc)
    render inertia: "Products/Index", props: {
      products: products.map { |prod| serialize(prod) }
    }
  end

  def new
    authorize Product

    render inertia: "Products/Form", props: {
      product:      {},
      credit_types: serialize_credit_types,
      currencies:   serialize_currencies,
      integrations: serialize_integrations,
      errors:       {}
    }
  end

  def create
    authorize Product

    product = Product.new(product_params)
    if product.save
      sync_prices(product)
      sync_integrations(product)
      redirect_to products_path, notice: "Produto criado."
    else
      render inertia: "Products/Form", props: {
        product:      product_params,
        credit_types: serialize_credit_types,
        currencies:   serialize_currencies,
        integrations: serialize_integrations,
        errors:       product.errors.as_json
      }
    end
  end

  def edit
    authorize @product

    render inertia: "Products/Form", props: {
      product:      serialize(@product),
      credit_types: serialize_credit_types,
      currencies:   serialize_currencies,
      integrations: serialize_integrations,
      errors:       {}
    }
  end

  def update
    authorize @product

    if @product.update(product_params)
      sync_prices(@product)
      sync_integrations(@product)
      redirect_to products_path, notice: "Produto atualizado."
    else
      render inertia: "Products/Form", props: {
        product:      serialize(@product),
        credit_types: serialize_credit_types,
        currencies:   serialize_currencies,
        integrations: serialize_integrations,
        errors:       @product.errors.as_json
      }
    end
  end

  def destroy
    authorize @product

    @product.update!(active: false)
    redirect_to products_path, notice: "Produto desativado."
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name, :description, :product_type, :credit_type_id, :credit_quantity, :active
    )
  end

  def serialize(prod)
    ct = prod.credit_type
    {
      id:              prod.id,
      name:            prod.name,
      description:     prod.description,
      product_type:    prod.product_type,
      credit_type_id:  prod.credit_type_id,
      credit_type:     ct ? { id: ct.id, label: ct.label, unit: ct.unit } : nil,
      credit_quantity: prod.credit_quantity,
      active:          prod.active,
      integration_ids: prod.product_integrations.pluck(:integration_id),
      prices:          serialize_product_prices(prod)
    }
  end

  def serialize_product_prices(prod)
    prod.product_prices.includes(:currency).map do |price|
      {
        currency_id:     price.currency_id,
        currency_code:   price.currency.code,
        currency_symbol: price.currency.symbol,
        amount_cents:    price.amount_cents,
        amount:          price.amount_in_base
      }
    end
  end

  def serialize_credit_types
    CreditType.all.map { |ct| { id: ct.id, key: ct.key, label: ct.label, unit: ct.unit } }
  end

  def serialize_integrations
    Integration.active.map { |i| { id: i.id, name: i.name, url: i.url } }
  end

  def serialize_currencies
    Currency.active.map { |cur| { id: cur.id, code: cur.code, name: cur.name, symbol: cur.symbol } }
  end

  def sync_prices(product)
    return unless params[:prices].present?

    params[:prices].each do |currency_id, amount_cents|
      next if amount_cents.blank?

      price = product.product_prices.find_or_initialize_by(currency_id:)
      price.update!(amount_cents: amount_cents.to_i)
    end
  end

  def sync_integrations(product)
    product.product_integrations.destroy_all
    Array(params[:integration_ids]).each do |integration_id|
      product.product_integrations.create!(integration_id:)
    end
  end
end
