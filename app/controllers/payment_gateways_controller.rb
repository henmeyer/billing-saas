class PaymentGatewaysController < ApplicationController
  before_action :require_admin!
  before_action :set_gateway, only: [:edit, :update, :destroy]

  def index
    render inertia: "PaymentGateways/Index", props: {
      gateways: PaymentGateway.order(:provider).map { |g| serialize(g) }
    }
  end

  def new
    render inertia: "PaymentGateways/Form", props: {
      gateway:   {},
      providers: PaymentGateway::PROVIDERS,
      errors:    {}
    }
  end

  def create
    gateway = PaymentGateway.new(provider: params[:gateway][:provider],
                                 active:   true)
    gateway.api_key = params[:gateway][:api_key] if params[:gateway][:api_key].present?
    apply_gateway_params(gateway)

    if gateway.save
      redirect_to payment_gateways_path, notice: "Gateway configurado."
    else
      render inertia: "PaymentGateways/Form", props: {
        gateway:   { provider: params[:gateway][:provider] },
        providers: PaymentGateway::PROVIDERS,
        errors:    gateway.errors.as_json
      }
    end
  end

  def edit
    render inertia: "PaymentGateways/Form", props: {
      gateway:   serialize(@gateway),
      providers: PaymentGateway::PROVIDERS,
      errors:    {}
    }
  end

  def update
    @gateway.api_key = params[:gateway][:api_key] if params[:gateway][:api_key].present?
    @gateway.active = params[:gateway][:active] if params[:gateway].key?(:active)
    apply_gateway_params(@gateway)

    if @gateway.save
      redirect_to payment_gateways_path, notice: "Gateway atualizado."
    else
      render inertia: "PaymentGateways/Form", props: {
        gateway:   serialize(@gateway),
        providers: PaymentGateway::PROVIDERS,
        errors:    @gateway.errors.as_json
      }
    end
  end

  def destroy
    @gateway.update!(active: false)
    redirect_to payment_gateways_path, notice: "Gateway desativado."
  end

  private

  def set_gateway
    @gateway = PaymentGateway.find(params[:id])
  end

  def serialize(gateway)
    {
      id:              gateway.id,
      provider:        gateway.provider,
      active:          gateway.active,
      last_four:       nil,
      sandbox:         gateway.gateway_data.fetch("sandbox", true),
      is_dlocal_go:    gateway.provider == "dlocal_go",
      default_country: gateway.gateway_data["default_country"]
    }
  end

  def apply_gateway_params(gateway)
    p = params[:gateway]
    gateway.gateway_data["sandbox"] = p[:sandbox] == "true" if p.key?(:sandbox)
    return unless gateway.provider == "dlocal_go"

    gateway.secret_key = p[:secret_key] if p[:secret_key].present?
    gateway.gateway_data["default_country"] = p[:default_country] if p[:default_country].present?
  end
end
