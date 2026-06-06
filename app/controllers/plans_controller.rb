class PlansController < ApplicationController
  before_action :require_admin!
  before_action :set_plan, only: %i[show edit update destroy]

  def index
    plans = Plan.active
                .includes(:plan_licenses, :plan_credits,
                          plan_licenses: :license_type, plan_credits: :credit_type)
                .order(price_cents: :asc)
                .map { |p| serialize_plan(p) }

    render inertia: "Plans/Index", props: { plans: }
  end

  def new
    render inertia: "Plans/Form", props: {
      plan:          serialize_plan(Plan.new),
      license_types: serialize_license_types,
      credit_types:  serialize_credit_types,
      feature_types: serialize_feature_types,
      integrations:  serialize_integrations,
      errors:        {}
    }
  end

  def create
    plan = Plan.new(plan_params)

    if plan.save
      sync_licenses_and_credits(plan)
      sync_features(plan)
      sync_integrations(plan)
      redirect_to plans_path, notice: "Plano criado com sucesso."
    else
      render inertia: "Plans/Form", props: {
        plan:          plan_params.merge(id: nil),
        license_types: serialize_license_types,
        credit_types:  serialize_credit_types,
        feature_types: serialize_feature_types,
        integrations:  serialize_integrations,
        errors:        plan.errors.as_json
      }
    end
  end

  def edit
    render inertia: "Plans/Form", props: {
      plan:          serialize_plan(@plan),
      license_types: serialize_license_types,
      credit_types:  serialize_credit_types,
      feature_types: serialize_feature_types,
      integrations:  serialize_integrations,
      errors:        {}
    }
  end

  def update
    if @plan.update(plan_params)
      sync_licenses_and_credits(@plan)
      sync_features(@plan)
      sync_integrations(@plan)
      redirect_to plans_path, notice: "Plano atualizado."
    else
      render inertia: "Plans/Form", props: {
        plan:          serialize_plan(@plan).merge(plan_params),
        license_types: serialize_license_types,
        credit_types:  serialize_credit_types,
        feature_types: serialize_feature_types,
        integrations:  serialize_integrations,
        errors:        @plan.errors.as_json
      }
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

  def serialize_plan(plan)
    {
      id:              plan.id,
      name:            plan.name,
      description:     plan.description,
      price_cents:     plan.price_cents,
      price:           plan.price_in_reais,
      billing_cycle:   plan.billing_cycle,
      trial_days:      plan.trial_days,
      active:          plan.active,
      licenses:        plan.plan_licenses.map do |pl|
        { license_type_id: pl.license_type_id, quantity: pl.quantity,
          label: pl.license_type&.label }
      end,
      credits:         plan.plan_credits.map do |pc|
        { credit_type_id: pc.credit_type_id, quantity: pc.quantity, rollover: pc.rollover,
          label: pc.credit_type&.label }
      end,
      features:        plan.plan_features.map do |pf|
        { feature_type_id: pf.feature_type_id, enabled: pf.enabled }
      end,
      integration_ids: plan.plan_integrations.pluck(:integration_id)
    }
  end

  def serialize_license_types
    LicenseType.all.map { |lt| { id: lt.id, key: lt.key, label: lt.label, unit: lt.unit } }
  end

  def serialize_credit_types
    CreditType.all.map { |ct| { id: ct.id, key: ct.key, label: ct.label, unit: ct.unit } }
  end

  def serialize_feature_types
    FeatureType.all.map { |ft| { id: ft.id, key: ft.key, label: ft.label } }
  end

  def serialize_integrations
    Integration.active.map { |i| { id: i.id, name: i.name, url: i.url } }
  end

  def sync_licenses_and_credits(plan)
    if params[:licenses].present?
      params[:licenses].each do |license_type_id, quantity|
        pl = plan.plan_licenses.find_or_initialize_by(license_type_id:)
        pl.update!(quantity: quantity.to_i)
      end
    end

    return unless params[:credits].present?

    params[:credits].each do |credit_type_id, data|
      pc = plan.plan_credits.find_or_initialize_by(credit_type_id:)
      pc.update!(quantity: data[:quantity].to_i, rollover: data[:rollover] == "true")
    end
  end

  def sync_features(plan)
    return unless params[:features].present?

    params[:features].each do |feature_type_id, enabled|
      pf = plan.plan_features.find_or_initialize_by(feature_type_id:)
      pf.update!(enabled: ["true", true].include?(enabled))
    end
  end

  def sync_integrations(plan)
    plan.plan_integrations.destroy_all
    Array(params[:integration_ids]).each do |integration_id|
      plan.plan_integrations.create!(integration_id:)
    end
  end

end
