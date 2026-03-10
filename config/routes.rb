Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Sentry SDK ingest API
  scope "api/:project_id" do
    post "envelope/", to: "api/ingest#envelope", as: :sentry_envelope
    post "store/", to: "api/ingest#store", as: :sentry_store
  end

  # Dashboard
  root "dashboard#index"
  get "health", to: "dashboard#health"
  get "stats", to: "dashboard#stats"

  # Errors
  resources :errors, only: [:index, :show] do
    member do
      post :resolve
      post :ignore
      post :reopen
    end
  end

  # Performance
  resources :performance, only: [:index, :show]

  # Alerts
  resources :alerts do
    member do
      post :toggle
      post :test
    end
  end

  # Projects
  resources :projects, only: [:index, :new, :create, :show, :destroy]
end
