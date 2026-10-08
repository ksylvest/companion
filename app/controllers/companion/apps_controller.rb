# frozen_string_literal: true

module Companion
  class AppsController < ApplicationController
    def index
      @apps = Companion.config.apps.values
    end

    def show
      @app = Companion.config.apps.values.find { |app| app.name.to_s == params[:id] }
      raise ActionController::RoutingError, "unknown app #{params[:id].inspect}" unless @app

      @sample = @app.sample
    end
  end
end
