class ProductsController < ApplicationController
  before_action :require_admin!
  before_action :set_product, only: [:edit, :update, :destroy]

  def index
    products = Product.includes(:credit_type).order(name: :asc)
    render inertia: "Products/Index", props: {
      products: products.map { |p| serialize(p) }
    }
  end

  def new
    render inertia: "Products/Form", props: {
      product:      {},
      credit_types: serialize_credit_types,
      errors:       {}
    }
  end

  def create
    product = Product.new(product_params)
    if product.save
      redirect_to products_path, notice: "Produto criado."
    else
      render inertia: "Products/Form", props: {
        product:      product_params,
        credit_types: serialize_credit_types,
        errors:       product.errors.as_json
      }
    end
  end

  def edit
    render inertia: "Products/Form", props: {
      product:      serialize(@product),
      credit_types: serialize_credit_types,
      errors:       {}
    }
  end

  def update
    if @product.update(product_params)
      redirect_to products_path, notice: "Produto atualizado."
    else
      render inertia: "Products/Form", props: {
        product:      serialize(@product),
        credit_types: serialize_credit_types,
        errors:       @product.errors.as_json
      }
    end
  end

  def destroy
    @product.update!(active: false)
    redirect_to products_path, notice: "Produto desativado."
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name, :description, :price_cents, :currency,
      :product_type, :credit_type_id, :credit_quantity, :active
    )
  end

  def serialize(p)
    {
      id:              p.id,
      name:            p.name,
      description:     p.description,
      price_cents:     p.price_cents,
      price:           p.price_cents / 100.0,
      product_type:    p.product_type,
      credit_type_id:  p.credit_type_id,
      credit_type:     p.credit_type ? { id: p.credit_type.id, label: p.credit_type.label, unit: p.credit_type.unit } : nil,
      credit_quantity: p.credit_quantity,
      active:          p.active
    }
  end

  def serialize_credit_types
    CreditType.all.map { |ct| { id: ct.id, key: ct.key, label: ct.label, unit: ct.unit } }
  end

end
