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

    def create_customer(customer)              = raise NotImplementedError
    def create_subscription(customer, plan)   = raise NotImplementedError
    def cancel_subscription(sub_id)           = raise NotImplementedError
    def update_subscription(sub_id, new_plan) = raise NotImplementedError
    def create_charge(customer, amount_cents) = raise NotImplementedError

    def self.for(provider)
      case provider.to_s
      when "stripe" then Gateways::StripeAdapter.new
      when "asaas"  then Gateways::AsaasAdapter.new
      else raise ArgumentError, "Gateway '#{provider}' não suportado"
      end
    end
  end
end
