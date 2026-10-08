# frozen_string_literal: true

module Companion
  # Holds the set of registered apps.
  class Configuration
    # @return [Hash{Symbol => App}] registered apps keyed by name
    attr_reader :apps

    def initialize
      @apps = {}
    end

    # Registers an app, replacing any existing app with the same name.
    #
    # @param name [Symbol]
    # @yieldparam app [App] the new app, for setting its options
    # @raise [ConfigurationError] if the app is invalid after the block runs
    # @return [App]
    def app(name)
      app = App.new(name)
      yield(app) if block_given?
      app.validate!
      @apps[app.name] = app
    end
  end
end
