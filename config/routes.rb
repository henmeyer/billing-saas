require "sidekiq/web"

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
    resources :subscriptions, only: %i[new create edit update destroy]
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
  end
  resources :api_keys, only: [:index, :create, :destroy]
  resources :payment_gateways
  resources :products

  resources :imports, only: [:index, :create, :show] do
    member do
      post :decide
      post :execute
    end
  end

  # Superadmin
  namespace :superadmin do
    root "dashboard#index"

    resources :accounts, only: %i[index show edit update] do
      member do
        post :suspend
        post :activate
      end
    end

    resources :users, only: [:index, :show] do
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
    end
  end
end
