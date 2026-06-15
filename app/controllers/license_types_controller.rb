class LicenseTypesController < ApplicationController
  before_action :require_admin!
  before_action :set_license_type, only: [:edit, :update, :destroy]

  def index
    render inertia: "LicenseTypes/Index", props: {
      license_types: LicenseType.order(:label).map { |lt| serialize(lt) }
    }
  end

  def new
    render inertia: "LicenseTypes/Form", props: {
      license_type: {},
      errors:       {}
    }
  end

  def create
    lt = LicenseType.new(license_type_params)
    if lt.save
      redirect_to license_types_path, notice: "Tipo de licença criado."
    else
      render inertia: "LicenseTypes/Form", props: {
        license_type: license_type_params,
        errors:       lt.errors.as_json
      }
    end
  end

  def edit
    render inertia: "LicenseTypes/Form", props: {
      license_type: serialize(@license_type),
      errors:       {}
    }
  end

  def update
    if @license_type.update(license_type_params)
      redirect_to license_types_path, notice: "Tipo de licença atualizado."
    else
      render inertia: "LicenseTypes/Form", props: {
        license_type: serialize(@license_type),
        errors:       @license_type.errors.as_json
      }
    end
  end

  def destroy
    @license_type.destroy!
    redirect_to license_types_path, notice: "Tipo de licença removido."
  rescue ActiveRecord::InvalidForeignKey
    redirect_to license_types_path, alert: "Não é possível remover: em uso por planos ou integrações."
  end

  private

  def set_license_type
    @license_type = LicenseType.find(params[:id])
  end

  def license_type_params
    params.require(:license_type).permit(:key, :label, :unit)
  end

  def serialize(lt)
    { id: lt.id, key: lt.key, label: lt.label, unit: lt.unit }
  end
end
