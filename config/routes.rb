Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # No host in the URL: mint one and redirect so the UUID lives in the URL.
  root "hosts#bootstrap"

  # Cross-host, read-only stats dashboard. The page itself is public; its data is
  # gated by a token the browser sends from localStorage (see DashboardController).
  get "dashboard"      => "dashboard#index"
  get "dashboard/data" => "dashboard#data"

  # /hosts/:uuid is the app. Possessing the UUID authenticates you as that
  # host's admin (see ApplicationController#current_role).
  resources :hosts, param: :uuid, only: [ :show, :update ] do
    member do
      get  :state
      post :nominate
      post :undo
      post :send_off
    end

    resources :players, only: [ :create, :destroy, :update ] do
      member do
        patch :adjust_tickets
        patch :gift
        patch :ungift
        patch :promote
        patch :demote
        patch :claim
      end
    end

    resources :logs, only: [ :index ]
  end

  # Player's limited-access view, authenticated by their own UUID. The host UUID
  # never appears in these URLs.
  scope "player/:player_uuid", as: :player do
    get   "",         to: "hosts#show",         as: ""
    patch "",         to: "hosts#update"
    get   "state",    to: "hosts#state",        as: :state
    post  "nominate", to: "hosts#nominate",     as: :nominate
    post  "undo",     to: "hosts#undo",         as: :undo
    post  "send_off", to: "hosts#send_off",     as: :send_off
    post  "players",  to: "players#create",     as: :players
    patch  "players/:id",                to: "players#update",         as: :update
    delete "players/:id",                to: "players#destroy",        as: :destroy
    patch "players/:id/adjust_tickets", to: "players#adjust_tickets", as: :adjust_tickets
    patch "players/:id/gift",          to: "players#gift",           as: :gift
    patch "players/:id/ungift",        to: "players#ungift",         as: :ungift
    patch "players/:id/promote",       to: "players#promote",        as: :promote
    patch "players/:id/demote",        to: "players#demote",         as: :demote
    get   "logs",     to: "logs#index",         as: :logs
  end
end
