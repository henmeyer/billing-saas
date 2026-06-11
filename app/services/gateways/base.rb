module Gateways
  class Base
    class NotImplementedError < StandardError; end

    class GatewayError < StandardError
      attr_reader :code

      def initialize(msg, code: nil)
        super(msg)
        @code = code
      end
    end

    def create_customer(customer) = raise NotImplementedError
    def create_subscription(customer, plan, amount_cents:)  = raise NotImplementedError
    def cancel_subscription(sub_id)                         = raise NotImplementedError
    def update_subscription(sub_id, new_plan, amount_cents:) = raise NotImplementedError
    def create_charge(customer, amount_cents, **opts) = raise NotImplementedError

    # Testa conectividade com o gateway. Retorna { success: true/false, message: "..." }
    def test_connection
      raise NotImplementedError
    end

    def self.for(provider)
      case provider.to_s
      when "stripe"    then Gateways::StripeAdapter.new
      when "asaas"     then Gateways::AsaasAdapter.new
      when "dlocal_go" then Gateways::DlocalGoAdapter.new
      else raise ArgumentError, "Gateway '#{provider}' não suportado"
      end
    end
  end
end
