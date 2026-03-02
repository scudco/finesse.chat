Rails.application.routes.draw do
  resources :messages, only: %i[ index create update destroy ] do
    collection do
      get :older
      get :newer
      post :bot_storm
    end
  end
  resource :session, only: [:destroy]

  get "up" => "rails/health#show", as: :rails_health_check

  root "messages#index"

  # Silence Chrome DevTools well-known probe.
  get "/.well-known/appspecific/com.chrome.devtools.json",
      to: proc { [204, {}, []] }
end
