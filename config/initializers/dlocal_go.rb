# frozen_string_literal: true

# dLocal Go: credenciais são configuradas per-tenant no adapter (DlocalGoAdapter).
# O setup global NÃO é usado porque cada conta tem suas próprias API keys.
# Este initializer existe apenas para definir defaults seguros.
DlocalGo.setup do |config|
  config.supported_countries = %w[BR AR CL CO MX PE UY]
end
