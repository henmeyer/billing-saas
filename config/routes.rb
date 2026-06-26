require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions:      "users/sessions"
  }

  # Sidekiq dashboard (admin only)
  authenticate :user, lambda(&:superadmin?) do
    mount Sidekiq::Web => "/sidekiq"
  end

  # App principal
  root "dashboard#index"

  resources :currencies
  resources :plans do
    resources :plan_licenses, shallow: true
    resources :plan_credits,  shallow: true
  end

  resources :license_types
  resources :credit_types
  resources :feature_types
  resources :subscriptions, only: [:index]
  resources :customers do
    resources :subscriptions, only: %i[new create edit update destroy] do
      member do
        post :migrate_to_billing
      end
    end
    resources :customer_products, only: [:create]
  end
  resources :integrations do
    resources :integration_api_keys, only: [:index, :create, :destroy]
    resources :webhook_tests,
              only:       [:create],
              controller: "integrations/webhook_tests" do
      collection do
        get :logs
      end
    end
    resources :webhook_logs, only: [:index], controller: "integrations/webhook_logs"
  end
  resources :api_keys, only: [:index, :create, :destroy]
  resources :payment_gateways do
    member do
      post :test
    end
  end
  resources :products

  resources :imports, only: [:index, :create, :show] do
    member do
      post :decide
      post :execute
    end
  end

  resources :account_users, only: %i[index new create edit update destroy]

  resource :profile, only: %i[show update], controller: "profile" do
    delete :destroy_avatar, on: :member
  end

  # Superadmin
  namespace :superadmin do
    root "dashboard#index"

    resources :accounts, only: %i[index show new create edit update] do
      member do
        post :suspend
        post :activate
      end
    end

    resources :users, only: %i[index show new create edit update] do
      member do
        post :impersonate
      end
    end

    resources :super_admins, only: %i[index new create destroy]
  end

  get  "/impersonation/enter", to: "superadmin/impersonations#enter",
                               as: :impersonation_enter
  post "/impersonation/stop",  to: "superadmin/impersonations#stop",
                               as: :impersonation_stop

  # Webhooks de entrada (sem auth de usuário)
  namespace :webhooks do
    post "/asaas",       to: "asaas#receive"
    post "/stripe",      to: "stripe#receive"
    post "/dlocal_go",   to: "dlocal_go#receive"
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
      post "/portal/sessions",                        to: "portal_sessions#create"
    end
  end

  # Portal do cliente externo
  get "/portal_expired", to: "portal/sessions#expired", as: :portal_expired

  scope "/portal/:token", module: "portal" do
    get "/",           to: "dashboard#show", as: :portal_dashboard
    resources :plans,  only: [:index] do
      member { put :update }
    end
    resources :products, only: [:index, :create]
    get  "/checkout/:charge_id",        to: "checkouts#show",   as: :portal_checkout
    get  "/checkout/:charge_id/status", to: "checkouts#status", as: :portal_checkout_status
    resources :invoices, only: [:index]
    resource  :subscription, only: [:update, :destroy]
    resource  :conversion,   only: [:new, :create]
    delete "/logout", to: "sessions#destroy", as: :portal_logout
  end
end
