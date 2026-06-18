class CustomerProductsController < ApplicationController
  before_action :require_admin!

  def create
    authorize Customer, :show?

    customer = policy_scope(Customer).find(params[:customer_id])
    product  = policy_scope(Product).find(params[:product_id])

    result = Products::PurchaseService.call(customer: customer, product: product)

    if result.success?
      redirect_to customer_path(customer), notice: "#{product.name} adicionado ao cliente."
    else
      redirect_to customer_path(customer), alert: result.errors.join(", ")
    end
  end
end
