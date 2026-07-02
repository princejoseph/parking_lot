Rails.application.routes.draw do
  mount Hyperstack::Engine => '/hyperstack'

  namespace :api do
    get "spots", to: "spots#index"
    match "spots/:id", to: "spots#update", via: %i[post put patch]
  end

  get "sensor", to: "sensor#show"

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
