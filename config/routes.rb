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

    resources :players, only: [ :create, :destroy ] do
      member do
        patch :toggle_room
        patch :adjust_tickets
      end
    end
  end
end
