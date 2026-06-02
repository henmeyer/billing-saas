class PlansController < ApplicationController
  before_action :require_admin!
  before_action :set_plan, only: %i[show edit update destroy]

  def index
    @plans = Plan.active.includes(:plan_licenses, :plan_credits)
                 .order(price_cents: :asc)
  end

  def show
  end

  def new
    @plan = Plan.new
  end

  def create
    @plan = Plan.new(plan_params)

    if @plan.save
      redirect_to @plan, notice: "Plano criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to @plan, notice: "Plano atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plan.archive!
    redirect_to plans_path, notice: "Plano arquivado."
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(
      :name, :description, :price_cents, :currency,
      :billing_cycle, :trial_days, :active
    )
  end

  def require_admin!
    redirect_to root_path, alert: "Acesso negado." unless current_user.admin?
  end
end
