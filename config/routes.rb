require "sidekiq/web"

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions:      "users/sessions"
  }

  # Sidekiq dashboard (admin only)
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # App principal
  root "dashboard#index"

  resources :plans do
    resources :plan_licenses, shallow: true
    resources :plan_credits,  shallow: true
  end

  resources :license_types
  resources :credit_types
  resources :customers do
    resources :subscriptions, shallow: true
  end
  resources :integrations
  resources :api_keys, only: [:index, :create, :destroy]
  resources :payment_gateways

  # Webhooks de entrada (sem auth de usuário)
  namespace :webhooks do
    post "/asaas",       to: "asaas#receive"
    post "/stripe",      to: "stripe#receive"
    post "/omnichannel", to: "omnichannel#receive"
  end

  # API externa (auth por API key)
  namespace :api do
    namespace :v1 do
      get  "/customers/:external_id/credits",         to: "credits#show"
      post "/customers/:external_id/credits/report",  to: "credits#report"
      get  "/customers/:external_id/licenses",        to: "licenses#show"
      post "/customers/:external_id/licenses/report", to: "licenses#report"
      get  "/customers/:external_id/subscription",    to: "subscriptions#show"
    end
  end
end
