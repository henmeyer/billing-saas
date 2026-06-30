class PaymentGatewaysController < ApplicationController
  # #test é uma verificação de conectividade read-only (apenas chama
  # adapter.test_connection, sem alterar estado) e já é protegida por
  # autenticação + autorização Pundit. A verificação de CSRF é dispensada
  # apenas nesta action porque a chamada vem de um fetch AJAX e o token do
  # meta tag pode não estar disponível no contexto Inertia.
  skip_before_action :verify_authenticity_token, only: :test

  before_action :require_admin!
  before_action :set_gateway, only: %i[edit update destroy test]

  def index
    render inertia: "PaymentGateways/Index", props: {
      gateways: policy_scope(PaymentGateway).order(:provider).map { |g| serialize(g) }
    }
  end

  def new
    authorize PaymentGateway

    render inertia: "PaymentGateways/Form", props: {
      gateway:   {},
      providers: PaymentGateway::PROVIDERS,
      errors:    {}
    }
  end

  def create
    authorize PaymentGateway

    gateway = PaymentGateway.new(provider: params[:provider],
                                 active:   true)
    gateway.api_key = params[:api_key] if params[:api_key].present?
    apply_gateway_params(gateway)

    if gateway.save
      redirect_to payment_gateways_path, notice: "Gateway configurado."
    else
      render inertia: "PaymentGateways/Form", props: {
        gateway:   { provider: params[:provider] },
        providers: PaymentGateway::PROVIDERS,
        errors:    gateway.errors.as_json
      }
    end
  end

  def edit
    authorize @gateway

    render inertia: "PaymentGateways/Form", props: {
      gateway:   serialize(@gateway),
      providers: PaymentGateway::PROVIDERS,
      errors:    {}
    }
  end

  def update
    authorize @gateway

    @gateway.api_key = params[:api_key] if params[:api_key].present?
    @gateway.active = params[:active] if params.key?(:active)
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
    authorize @gateway

    @gateway.update!(active: false)
    redirect_to payment_gateways_path, notice: "Gateway desativado."
  end

  def test
    authorize @gateway, :update?

    adapter = Gateways::Base.for(@gateway.provider)
    result  = adapter.test_connection

    render json: result
  rescue StandardError => e
    render json: { success: false, message: e.message }
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
    p = params
    gateway.gateway_data["sandbox"] = p[:sandbox] == "true" if p.key?(:sandbox)
    return unless gateway.provider == "dlocal_go"

    gateway.secret_key = p[:secret_key] if p[:secret_key].present?
    gateway.gateway_data["default_country"] = p[:default_country] if p[:default_country].present?
  end
end
