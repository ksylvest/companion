# frozen_string_literal: true

Rails.application.routes.draw do
  mount Companion::Engine, at: "/companion"
  mount Companion::Engine.app(:greeter), at: "/greeter"
end
