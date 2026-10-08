# frozen_string_literal: true

require "rails_helper"

RSpec.describe Companion::Configuration do
  subject(:configuration) { described_class.new }

  describe "#app" do
    it "registers a validated app under its name" do
      registered = nil

      returned = configuration.app(:dashboard) do |app|
        app.command = "true"
        app.directory = "/tmp"
        registered = app
      end

      expect(returned).to equal(registered)
      expect(registered.name).to eq(:dashboard)
      expect(registered.directory).to eq("/tmp")
      expect(configuration.apps).to eq({ dashboard: registered })
    end

    it "leaves the registry empty when validation fails" do
      expect { configuration.app(:dashboard) }.to raise_error(
        Companion::ConfigurationError,
        "app :dashboard requires a command",
      )
      expect(configuration.apps).to be_empty
    end
  end
end
