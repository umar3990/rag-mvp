Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  resources :documents, only: %i[ index new create show ] do
    member do
      post :retry
    end
  end
  resources :conversations, only: %i[ index create show ] do
    resources :messages, only: %i[ create ]
  end
  resources :reviews, only: %i[ index ], controller: "message_reviews" do
    member do
      patch :approve
      patch :reject
    end
  end

  # n8n's Gmail relay posts here -- :webhook_token both identifies and
  # authenticates the organization in one step (see docs/webhook-contract.md).
  post "webhooks/gmail/:webhook_token" => "gmail_webhooks#create", as: :gmail_webhook
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Action Cable -- needed for Turbo Streams broadcasts (live status
  # updates) to actually reach the browser over a WebSocket. Not
  # auto-mounted by default in this Rails version, so wired explicitly.
  mount ActionCable.server => "/cable"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
