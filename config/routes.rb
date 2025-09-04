Rails.application.routes.draw do
  # get "home/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  devise_for :users, controllers: {
    registrations: "users/registrations",
    session: "users/sessions",
    omniauth_callbacks: "users/omniauth_callbacks"
   }

  # devise_scope :user do
  #   delete "users/sign_out", to: "devise/sessions#destroy"
  # end

  resources :clients do
    collection do
      get :search
    end
    member do
      delete 'photos/:photo_id', to: 'clients#delete_photo', as: 'delete_photo'
      delete 'delete_all_photos', to: 'clients#delete_all_photos'
    end
    resources :service_notes do
      resources :formula_steps, only: [:create, :update, :destroy]
    end
  end

  resources :appointments do
    collection do
      get :calendar
      get :by_date
      get :history
      get :free_slots
    end
  end

  resources :slot_rules

  resources :services, except: [ :show ] do
    collection do
      get :main
      get :section
      get :filter
      get :preparations
      get :care_products

      post :create_preparation
      post :create_care_product
    end
  end

  resource :subscription, only: [] do
    get :wayforpay, to: "subscriptions#wayforpay_form"
    post :monthly,  to: "subscriptions#activate_monthly"
    post :yearly,   to: "subscriptions#activate_yearly"
    post :payment_callback, to: "subscriptions#payment_callback"
    delete :cancel, to: "subscriptions#cancel"
  end

  get '/admin', to: 'admin#index', as: :admin

  get "/settings", to: "settings#show"
  get "/settings/subscription", to: "settings#subscription", as: :settings_subscription

  resources :expenses, except: [ :show ]

  resource :analytics, only: [ :show ], controller: 'analytics' do
    get :expenses
    get :income
    get :balance
  end

  root to: "home#index"
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/privacy_policy", to: "static#privacy_policy"
  get "/terms", to: "static#terms"
  get "/about_us", to: "static#about_us"
  # Defines the root path route ("/")
  # root "posts#index"
end
