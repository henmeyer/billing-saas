FactoryBot.define do
  factory :currency do
    account
    code    { "BRL" }
    name    { "Real Brasileiro" }
    symbol  { "R$" }
    default { true }

    factory :usd_currency do
      code    { "USD" }
      name    { "Dólar Americano" }
      symbol  { "$" }
      default { false }
    end
  end
end
