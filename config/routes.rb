Rails.application.routes.draw do
  # devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  devise_for :users,
             controllers: {
               sessions: 'api/v1/auth/sessions',
               registrations: 'api/v1/auth/registrations'
             },
             path: 'api/v1/auth',
             defaults: { format: :json }

  namespace :api do
    namespace :v1 do
      resources :accounts, only: %i[index show create] do
        get 'balance', on: :collection
        post 'deposit', on: :collection
        post 'withdraw', on: :collection
        post 'transfer', on: :collection
        post 'hold', on: :collection
        post 'unhold', on: :collection
        post 'close', on: :collection

        resources :transactions, only: [:index, :show] do
          member do
            post :reverse
          end
        end
      end
    end
  end
end
