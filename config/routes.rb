Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # No host in the URL: mint one and redirect so the UUID lives in the URL.
  root "hosts#bootstrap"

  # /hosts/:uuid is the app. Possessing the UUID authenticates you as that
  # host's admin (see ApplicationController#current_role).
  resources :hosts, param: :uuid, only: [ :show ] do
    member do
      post :nominate
      post :undo
      post :send_off
    end

    resources :players, only: [ :create, :destroy, :update ] do
      member do
        patch :toggle_room
        patch :adjust_tickets
        patch :gift
        patch :ungift
      end
    end

    resources :logs, only: [ :index ]
  end

  # Player's limited-access view, authenticated by their own UUID. The host UUID
  # never appears in these URLs.
  scope "player/:player_uuid", as: :player do
    get   "",         to: "hosts#show",         as: ""
    post  "nominate", to: "hosts#nominate",     as: :nominate
    post  "undo",     to: "hosts#undo",         as: :undo
    post  "send_off", to: "hosts#send_off",     as: :send_off
    post  "players",  to: "players#create",     as: :players
    patch "players/:id/toggle_room", to: "players#toggle_room", as: :toggle_room
    patch "players/:id/gift",        to: "players#gift",        as: :gift
    patch "players/:id/ungift",      to: "players#ungift",      as: :ungift
    get   "logs",     to: "logs#index",         as: :logs
  end
end
