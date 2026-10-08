# frozen_string_literal: true

require "companion/version"
require "companion/process_sample"
require "companion/app"
require "companion/configuration"
require "companion/proxy"
require "companion/engine"

# Runs companion web apps alongside a Rails application and proxies requests to them.
module Companion
  # Base class for all Companion errors.
  class Error < StandardError; end

  # Raised when an app is misconfigured or looked up by an unknown name.
  class ConfigurationError < Error; end

  # Raised when an app exits or fails to listen while booting.
  class BootError < Error; end

  class << self
    # @return [Configuration] the memoized global configuration
    def config
      @config ||= Configuration.new
    end

    # @yieldparam config [Configuration]
    # @return [void]
    def configure
      yield(config)
    end

    # Looks up a registered app.
    #
    # @param name [Symbol]
    # @raise [ConfigurationError] if no app is registered under +name+
    # @return [App]
    def [](name)
      config.apps.fetch(name) { raise ConfigurationError, "unknown app #{name.inspect}" }
    end

    # Stops every registered app, keeping the configuration.
    #
    # @return [void]
    def stop
      config.apps.each_value(&:stop)
    end

    # Stops every app and discards the configuration.
    #
    # @return [void]
    def reset!
      stop
      @config = nil
    end
  end
end

at_exit { Companion.stop }
