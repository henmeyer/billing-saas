class CreditTypesController < ApplicationController
  before_action :require_admin!
  before_action :set_credit_type, only: [:edit, :update, :destroy]

  def index
    render inertia: "CreditTypes/Index", props: {
      credit_types: CreditType.order(:label).map { |ct| serialize(ct) }
    }
  end

  def new
    render inertia: "CreditTypes/Form", props: {
      credit_type: {},
      errors:      {}
    }
  end

  def create
    ct = CreditType.new(credit_type_params)
    if ct.save
      redirect_to credit_types_path, notice: "Tipo de crédito criado."
    else
      render inertia: "CreditTypes/Form", props: {
        credit_type: credit_type_params,
        errors:      ct.errors.as_json
      }
    end
  end

  def edit
    render inertia: "CreditTypes/Form", props: {
      credit_type: serialize(@credit_type),
      errors:      {}
    }
  end

  def update
    if @credit_type.update(credit_type_params)
      redirect_to credit_types_path, notice: "Tipo de crédito atualizado."
    else
      render inertia: "CreditTypes/Form", props: {
        credit_type: serialize(@credit_type),
        errors:      @credit_type.errors.as_json
      }
    end
  end

  def destroy
    @credit_type.destroy!
    redirect_to credit_types_path, notice: "Tipo de crédito removido."
  rescue ActiveRecord::InvalidForeignKey
    redirect_to credit_types_path, alert: "Não é possível remover: em uso por planos ou integrações."
  end

  private

  def set_credit_type
    @credit_type = CreditType.find(params[:id])
  end

  def credit_type_params
    params.require(:credit_type).permit(:key, :label, :unit, :reset_cycle)
  end

  def serialize(ct)
    { id: ct.id, key: ct.key, label: ct.label, unit: ct.unit, reset_cycle: ct.reset_cycle }
  end
end
