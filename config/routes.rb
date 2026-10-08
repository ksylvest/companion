# frozen_string_literal: true

Companion::Engine.routes.draw do
  root "apps#index"
  resources :apps, only: :show
end
