class CurrenciesController < ApplicationController
  before_action :require_admin!
  before_action :set_currency, only: [:edit, :update, :destroy]

  def index
    currencies = policy_scope(Currency).order(:code)
    render inertia: "Currencies/Index", props: {
      currencies: currencies.map { |c| serialize(c) }
    }
  end

  def new
    authorize Currency

    render inertia: "Currencies/Form", props: {
      currency: {}, errors: {}
    }
  end

  def create
    authorize Currency

    currency = Currency.new(currency_params)
    if currency.save
      redirect_to currencies_path, notice: "Moeda criada."
    else
      render inertia: "Currencies/Form", props: {
        currency: currency_params, errors: currency.errors.as_json
      }
    end
  end

  def edit
    authorize @currency

    render inertia: "Currencies/Form", props: {
      currency: serialize(@currency), errors: {}
    }
  end

  def update
    authorize @currency

    if @currency.update(currency_params)
      redirect_to currencies_path, notice: "Moeda atualizada."
    else
      render inertia: "Currencies/Form", props: {
        currency: serialize(@currency), errors: @currency.errors.as_json
      }
    end
  end

  def destroy
    authorize @currency

    @currency.update!(active: false)
    redirect_to currencies_path, notice: "Moeda desativada."
  end

  private

  def set_currency
    @currency = Currency.find(params[:id])
  end

  def currency_params
    params.require(:currency).permit(:code, :name, :symbol, :default, :active)
  end

  def serialize(currency)
    {
      id:      currency.id,
      code:    currency.code,
      name:    currency.name,
      symbol:  currency.symbol,
      default: currency.default,
      active:  currency.active
    }
  end
end
