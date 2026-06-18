class FeatureTypesController < ApplicationController
  before_action :require_admin!
  before_action :set_feature_type, only: [:edit, :update, :destroy]

  def index
    render inertia: "FeatureTypes/Index", props: {
      feature_types: policy_scope(FeatureType).order(:label).map { |ft| serialize(ft) }
    }
  end

  def new
    authorize FeatureType

    render inertia: "FeatureTypes/Form", props: {
      feature_type: {},
      errors:       {}
    }
  end

  def create
    authorize FeatureType

    ft = FeatureType.new(feature_type_params)
    if ft.save
      redirect_to feature_types_path, notice: "Feature criada."
    else
      render inertia: "FeatureTypes/Form", props: {
        feature_type: feature_type_params,
        errors:       ft.errors.as_json
      }
    end
  end

  def edit
    authorize @feature_type

    render inertia: "FeatureTypes/Form", props: {
      feature_type: serialize(@feature_type),
      errors:       {}
    }
  end

  def update
    authorize @feature_type

    if @feature_type.update(feature_type_params)
      redirect_to feature_types_path, notice: "Feature atualizada."
    else
      render inertia: "FeatureTypes/Form", props: {
        feature_type: serialize(@feature_type),
        errors:       @feature_type.errors.as_json
      }
    end
  end

  def destroy
    authorize @feature_type

    @feature_type.destroy!
    redirect_to feature_types_path, notice: "Feature removida."
  rescue ActiveRecord::InvalidForeignKey
    redirect_to feature_types_path, alert: "Não é possível remover: em uso por planos ou integrações."
  end

  private

  def set_feature_type
    @feature_type = FeatureType.find(params[:id])
  end

  def feature_type_params
    params.require(:feature_type).permit(:key, :label, :description)
  end

  def serialize(ft)
    { id: ft.id, key: ft.key, label: ft.label, description: ft.description }
  end
end
