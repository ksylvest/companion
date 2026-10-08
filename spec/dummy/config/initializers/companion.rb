# frozen_string_literal: true

Companion.configure do |config|
  config.app :greeter do |app|
    app.command = ->(port) { "rackup --port #{port}" }
    app.directory = Rails.root.join("companions", "greeter")
  end
end
