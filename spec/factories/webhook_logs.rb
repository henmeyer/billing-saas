FactoryBot.define do
  factory :webhook_log do
    integration
    customer
    event    { "payment.received" }
    payload  { { "amount" => 197 } }
    status   { "pending" }
    attempts { 1 }
    uuid     { SecureRandom.uuid }
  end
end
