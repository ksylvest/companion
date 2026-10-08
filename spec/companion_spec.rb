# frozen_string_literal: true

require "rails_helper"

RSpec.describe Companion do
  describe "errors" do
    it "shares one error hierarchy" do
      expect(Companion::ConfigurationError).to be < Companion::Error
      expect(Companion::BootError).to be < Companion::Error
      expect(Companion::Error).to be < StandardError
    end
  end

  describe ".config" do
    it "returns a memoized configuration" do
      expect(Companion.config).to be_a(Companion::Configuration)
      expect(Companion.config).to equal(Companion.config)
    end
  end

  describe ".configure" do
    it "yields the current configuration" do
      yielded = nil

      Companion.configure { |config| yielded = config }

      expect(yielded).to equal(Companion.config)
    end

    it "registers every app" do
      Companion.configure do |config|
        config.app(:one) { |app| app.command = "true" }
        config.app(:two) { |app| app.command = "true" }
      end

      expect(Companion[:one].name).to eq(:one)
      expect(Companion[:two].name).to eq(:two)
    end
  end

  describe ".[]" do
    before do
      Companion.configure do |config|
        config.app(:dashboard) { |app| app.command = "true" }
      end
    end

    it "finds an app by name" do
      expect(Companion[:dashboard].name).to eq(:dashboard)
    end

    it "raises when the app is unknown" do
      expect { Companion[:missing] }.to raise_error(Companion::ConfigurationError, "unknown app :missing")
    end

    it "does not convert string names" do
      expect { Companion["dashboard"] }.to raise_error(Companion::ConfigurationError, 'unknown app "dashboard"')
    end
  end

  describe ".stop" do
    it "stops every running app and keeps the configuration" do
      Companion.configure do |config|
        config.app(:one) { |app| app.command = ->(port) { server_command(port) } }
        config.app(:two) { |app| app.command = ->(port) { server_command(port) } }
      end
      companion_apps << Companion[:one] << Companion[:two]
      Companion[:one].start
      Companion[:two].start

      Companion.stop

      expect(Companion[:one].running?).to be(false)
      expect(Companion[:two].running?).to be(false)
      expect(Companion.config.apps.keys).to eq([ :one, :two ])
    end
  end

  describe ".reset!" do
    it "stops running apps and replaces the configuration" do
      Companion.configure do |config|
        config.app(:dashboard) { |app| app.command = ->(port) { server_command(port) } }
      end
      app = Companion[:dashboard]
      companion_apps << app
      app.start
      pid = app.pid
      original = Companion.config

      Companion.reset!

      expect(Companion.config).not_to equal(original)
      expect(Companion.config.apps).to be_empty
      expect { Companion[:dashboard] }.to raise_error(Companion::ConfigurationError)
      expect { Process.kill(0, pid) }.to raise_error(Errno::ESRCH)
    end
  end
end
