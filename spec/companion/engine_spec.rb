# frozen_string_literal: true

require "rails_helper"

RSpec.describe Companion::Engine do
  it "is an isolated Rails engine" do
    expect(described_class).to be < Rails::Engine
    expect(described_class.isolated?).to be(true)
    expect(described_class.engine_name).to eq("companion")
  end

  describe ".app" do
    it "proxies rack requests to the named companion app" do
      Companion.configure do |config|
        config.app(:dashboard) do |app|
          app.command = ->(port) { server_command(port) }
          app.boot_timeout = 5
        end
      end
      companion_apps << Companion[:dashboard]

      status, headers, body = described_class.app(:dashboard).call(rack_env("PATH_INFO" => "/health"))

      expect(status).to eq(200)
      expect(headers["content-type"]).to eq("application/json")
      expect(JSON.parse(body.first)).to include("method" => "GET", "target" => "/health")
    end

    it "raises when the named app is unknown" do
      endpoint = described_class.app(:missing)

      expect { endpoint.call(rack_env) }.to raise_error(Companion::ConfigurationError, "unknown app :missing")
    end
  end
end
