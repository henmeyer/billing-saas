module Gateways
  class ResolverService
    # Resolve o melhor gateway ativo para o cliente, baseado no país.
    #
    # Prioridade:
    #   País BR        → Asaas > dLocal Go > Stripe
    #   País LATAM (≠BR) → dLocal Go > Stripe
    #   Outros países  → Stripe > dLocal Go
    #
    # Retorna o provider string ("asaas", "dlocal_go", "stripe")
    # ou nil se nenhum gateway ativo disponível.

    LATAM_COUNTRIES = %w[
      AR BO BR CL CO CR DO EC SV GT HN MX NI PA PY PE UY VE
    ].freeze

    def self.call(account:, country:, currency_code: nil)
      new(account: account, country: country, currency_code: currency_code).call
    end

    def initialize(account:, country:, currency_code: nil)
      @account         = account
      @country         = country&.upcase || "BR"
      @currency_code   = currency_code&.upcase || "BRL"
      @active_gateways = @account.payment_gateways.active.pluck(:provider)
    end

    def call
      ranked_candidates.find { |provider| @active_gateways.include?(provider) }
    end

    # Retorna todos os candidatos ordenados por prioridade
    def ranked_candidates
      if brazil?
        %w[asaas dlocal_go stripe]
      elsif latam?
        %w[dlocal_go stripe]
      else
        %w[stripe dlocal_go]
      end
    end

    # Retorna os métodos de pagamento disponíveis para o gateway resolvido
    def self.payment_methods_for(provider:, country:)
      case provider
      when "asaas"
        [
          { id: "PIX",          label: "Pix", icon: "pix" },
          { id: "BOLETO",       label: "Boleto",                icon: "boleto" },
          { id: "CREDIT_CARD",  label: "Cartão de crédito",     icon: "card" }
        ]
      when "dlocal_go"
        methods = [{ id: "CARD", label: "Cartão de crédito", icon: "card" }]

        if country.upcase == "BR"
          methods.unshift(
            { id: "PIX",    label: "Pix",    icon: "pix" },
            { id: "BOLETO", label: "Boleto", icon: "boleto" }
          )
        elsif %w[AR CL CO MX PE UY].include?(country.upcase)
          methods << { id: "BANK_TRANSFER", label: "Transferência", icon: "bank" }
        end

        methods
      when "stripe"
        [{ id: "CARD", label: "Cartão de crédito", icon: "card" }]
      else
        []
      end
    end

    private

    def brazil?
      @country == "BR"
    end

    def latam?
      LATAM_COUNTRIES.include?(@country)
    end
  end
end
