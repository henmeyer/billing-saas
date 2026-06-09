class PlansController < ApplicationController
  before_action :require_admin!
  before_action :set_plan, only: %i[show edit update destroy]

  def index
    plans = Plan.active
                .includes(:plan_licenses, :plan_credits, :plan_prices,
                          plan_licenses: :license_type, plan_credits: :credit_type,
                          plan_prices: :currency)
                .order(name: :asc)
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
      currencies:    serialize_currencies,
      errors:        {}
    }
  end

  def create
    plan = Plan.new(plan_params)

    if plan.save
      sync_licenses_and_credits(plan)
      sync_features(plan)
      sync_integrations(plan)
      sync_prices(plan)
      sync_tiers(plan)
      redirect_to plans_path, notice: "Plano criado com sucesso."
    else
      render inertia: "Plans/Form", props: {
        plan:          plan_params.merge(id: nil),
        license_types: serialize_license_types,
        credit_types:  serialize_credit_types,
        feature_types: serialize_feature_types,
        integrations:  serialize_integrations,
        currencies:    serialize_currencies,
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
      currencies:    serialize_currencies,
      errors:        {}
    }
  end

  def update
    if @plan.update(plan_params)
      sync_licenses_and_credits(@plan)
      sync_features(@plan)
      sync_integrations(@plan)
      sync_prices(@plan)
      sync_tiers(@plan)
      redirect_to plans_path, notice: "Plano atualizado."
    else
      render inertia: "Plans/Form", props: {
        plan:          serialize_plan(@plan).merge(plan_params),
        license_types: serialize_license_types,
        credit_types:  serialize_credit_types,
        feature_types: serialize_feature_types,
        integrations:  serialize_integrations,
        currencies:    serialize_currencies,
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
      :name, :description, :billing_cycle, :trial_days, :active,
      :pricing_model, :pricing_license_type_id, :pricing_credit_type_id
    )
  end

  def serialize_plan(plan)
    {
      id:              plan.id,
      name:            plan.name,
      description:     plan.description,
      billing_cycle:   plan.billing_cycle,
      trial_days:      plan.trial_days,
      active:          plan.active,
      pricing_model:           plan.pricing_model,
      pricing_license_type_id: plan.pricing_license_type_id,
      pricing_credit_type_id:  plan.pricing_credit_type_id,
      licenses:                serialize_plan_licenses(plan),
      credits:                 serialize_plan_credits(plan),
      features:                plan.plan_features.map { |pf| { feature_type_id: pf.feature_type_id, enabled: pf.enabled } },
      integration_ids:         plan.plan_integrations.pluck(:integration_id),
      prices:                  serialize_plan_prices(plan),
      pricing_tiers:           serialize_plan_pricing_tiers(plan)
    }
  end

  def serialize_plan_licenses(plan)
    plan.plan_licenses.map do |pl|
      { license_type_id: pl.license_type_id, quantity: pl.quantity, label: pl.license_type&.label }
    end
  end

  def serialize_plan_credits(plan)
    plan.plan_credits.map do |pc|
      {
        credit_type_id:         pc.credit_type_id,
        credit_type_label:      pc.credit_type&.label,
        credit_type_key:        pc.credit_type&.key,
        unit:                   pc.credit_type&.unit,
        quantity:               pc.quantity,
        rollover:               pc.rollover,
        allow_extras:           pc.allow_extras,
        extra_unit_size:        pc.extra_unit_size,
        extra_unit_price_cents: pc.extra_unit_price_cents
      }
    end
  end

  def serialize_plan_prices(plan)
    plan.plan_prices.includes(:currency).map do |pp|
      {
        currency_id:     pp.currency_id,
        currency_code:   pp.currency.code,
        currency_symbol: pp.currency.symbol,
        default:         pp.currency.default,
        amount_cents:    pp.amount_cents,
        amount:          pp.amount_in_base
      }
    end
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

  def serialize_currencies
    Currency.active.map do |c|
      { id: c.id, code: c.code, name: c.name, symbol: c.symbol, default: c.default }
    end
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
      pc.update!(
        quantity:               data[:quantity].to_i,
        rollover:               ["true", true].include?(data[:rollover]),
        allow_extras:           ["true", true].include?(data[:allow_extras]),
        extra_unit_size:        data[:extra_unit_size].to_i,
        extra_unit_price_cents: data[:extra_unit_price_cents].to_i
      )
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

  def sync_prices(plan)
    return unless params[:prices].present?

    params[:prices].each do |currency_id, amount_cents|
      next if amount_cents.blank?

      pp = plan.plan_prices.find_or_initialize_by(currency_id:)
      pp.update!(amount_cents: amount_cents.to_i)
    end
  end

  def sync_tiers(plan)
    return unless params[:pricing_tiers].present?

    plan.plan_pricing_tiers.destroy_all

    params[:pricing_tiers].each_with_index do |tier_data, index|
      next if tier_data[:unit_amount_cents].blank?

      plan.plan_pricing_tiers.create!(
        currency_id:       tier_data[:currency_id],
        from_unit:         tier_data[:from_unit],
        to_unit:           tier_data[:to_unit].presence,
        unit_amount_cents: tier_data[:unit_amount_cents].to_i,
        position:          index
      )
    end
  end

  def serialize_plan_pricing_tiers(plan)
    plan.plan_pricing_tiers.includes(:currency).ordered.map do |t|
      {
        id:                t.id,
        currency_id:       t.currency_id,
        currency_code:     t.currency.code,
        currency_symbol:   t.currency.symbol,
        from_unit:         t.from_unit,
        to_unit:           t.to_unit,
        unit_amount_cents: t.unit_amount_cents,
        position:          t.position
      }
    end
  end
end
