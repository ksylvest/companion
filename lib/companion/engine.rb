# frozen_string_literal: true

module Companion
  # Rails integration for Companion.
  class Engine < ::Rails::Engine
    isolate_namespace Companion

    # Builds a Rack endpoint for mounting an app in the host's routes. The app
    # is looked up per request, so it may be registered after routes load.
    #
    # @example
    #   mount Companion::Engine.app(:dashboard), at: "/dashboard"
    #
    # @param name [Symbol] the registered app's name
    # @return [Proc] a Rack endpoint
    def self.app(name)
      ->(env) { Companion[name].proxy.call(env) }
    end
  end
end
