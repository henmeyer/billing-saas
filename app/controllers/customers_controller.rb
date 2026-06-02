class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update]

  def index
    @customers = Customer.includes(:subscriptions)
                         .order(name: :asc)
  end

  def show
    @subscription = @customer.active_subscription
    @charges      = @customer.charges.order(created_at: :desc).limit(10)
    @snapshots    = @customer.current_period&.credit_snapshots
                             &.includes(:credit_type) || []
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      redirect_to @customer, notice: "Cliente criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Cliente atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name, :email, :document, :phone, :external_id, :status, :notes
    )
  end
end
