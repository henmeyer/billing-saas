source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.4"

gem "bootsnap", require: false
gem "dotenv-rails", ">= 3.0.0"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "rails", "~> 7.1.6"

# Multi-tenancy
gem "acts_as_tenant"

# Auth
gem "bcrypt", "~> 3.1.7"
gem "devise"
gem "pundit"

# Frontend
gem "vite_rails"
gem "inertia_rails"

# Jobs
gem "redis", ">= 4.0.1"
gem "sidekiq"
gem "sidekiq-cron"

# HTTP client (para Asaas)
gem "httparty"

# Gateways
gem "stripe"
gem "dlocal_go"

# IA
gem "anthropic"

# Paginação
gem "kaminari"

# Segurança
gem "rack-attack"

gem "rswag-api"
gem "rswag-ui"

group :development, :test do
  gem "debug", platforms: %i[mri windows]
  gem "factory_bot_rails"
  gem "faker"
  gem "rspec-rails"
  gem "rswag-specs"
end

group :test do
  gem "shoulda-matchers"
  gem "webmock"
  gem "vcr"
  gem "pundit-matchers"
end

group :development do
  gem "web-console"
end
