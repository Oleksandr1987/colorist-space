Rails.application.routes.draw do

  devise_for :users,
           controllers: {
             registrations: "users/registrations",
             sessions: "users/sessions",
             omniauth_callbacks: "users/omniauth_callbacks"
           }

  resources :clients do
    resources :service_notes do
      member do
        delete "photos/:photo_id", to: "service_notes#delete_photo", as: :delete_photo
        post :add_ingredient
      end

      resources :formula_steps, only: [:create, :update, :destroy] do
        member do
          patch :clear_oxidant
          patch :clear_time
        end
      end
    end

    collection do
      get :search
      get :autocomplete
    end

    member do
      patch :make_primary
      delete "photos/:photo_id", to: "clients#delete_photo", as: "delete_photo"
      delete "delete_all_photos", to: "clients#delete_all_photos"
    end
  end

  resources :appointments do
    collection do
      get :all
      get :calendar
      get :by_date
      get :free_slots
    end
  end

  resources :slot_rules

  resources :services, except: [ :show ] do
    collection do
      get :main
      get :section
      get :filter
    end
  end

  resources :formula_products

  resources :care_products, except: [:show] do
    collection do
      get :options
    end
  end

  resource :subscription, only: [] do
    get :wayforpay, to: "subscriptions#wayforpay_form"
    post :monthly,  to: "subscriptions#activate_monthly"
    post :yearly,   to: "subscriptions#activate_yearly"
    post :payment_callback, to: "subscriptions#payment_callback"
    delete :cancel, to: "subscriptions#cancel"
  end

  get "/admin", to: "admin#index", as: :admin

  get "/settings", to: "settings#show"
  get "/settings/subscription", to: "settings#subscription", as: :settings_subscription

  resources :expenses, except: [ :show ]

  resource :analytics, controller: "analytics", only: [ :show ] do
    get :expenses
    get :income
    get :balance
  end

  root to: "home#index"

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/privacy_policy", to: "static#privacy_policy"
  get "/terms", to: "static#terms"
  get "/about_us", to: "static#about_us"

end
