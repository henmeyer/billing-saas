source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.4"

gem "rails", "~> 7.1.6"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# Multi-tenancy
gem "acts_as_tenant"

# Auth
gem "devise"
gem "bcrypt", "~> 3.1.7"

# Frontend
gem "vite_rails"

# Jobs
gem "sidekiq"
gem "redis", ">= 4.0.1"

# HTTP client (para Asaas)
gem "httparty"

# Gateways
gem "stripe"

# IA
gem "anthropic"

# Segurança
gem "rack-attack"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "debug", platforms: %i[mri windows]
end

group :development do
  gem "web-console"
end
