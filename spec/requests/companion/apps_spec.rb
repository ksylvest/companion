# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Companion::Apps", type: :request do
  after { Companion.reset! }

  describe "GET /companion" do
    it "renders an empty state when no apps are registered" do
      get "/companion"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No apps are registered.")
    end

    it "renders the status of each registered app" do
      Companion.configure do |config|
        config.app :idle do |app|
          app.command = "true"
        end

        config.app :server do |app|
          app.command = %(ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", ENV.fetch("PORT")); loop { server.accept.close }')
        end
      end
      Companion[:server].start

      get "/companion"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<tr id="app_idle">))
      expect(response.body).to include(%(<td>stopped</td>))
      expect(response.body).to include(%(<td>running</td>))
      expect(response.body).to include(Companion[:server].url)
      expect(response.body).to include(String(Companion[:server].pid))
    end

    it "renders directories relative to the Rails root" do
      Companion.configure do |config|
        config.app :nested do |app|
          app.command = "true"
          app.directory = Rails.root.join("companions", "greeter")
        end

        config.app :outside do |app|
          app.command = "true"
          app.directory = Rails.root.join("..", "support")
        end
      end

      get "/companion"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<td><code>companions/greeter</code></td>))
      expect(response.body).to include(%(<td><code>../support</code></td>))
    end

    it "links each app to its details page" do
      Companion.configure do |config|
        config.app :idle do |app|
          app.command = "true"
        end
      end

      get "/companion"

      expect(response.body).to include(%(<a href="/companion/apps/idle">idle</a>))
    end
  end

  describe "GET /companion/apps/:id" do
    it "renders the resource usage and processes of a running app" do
      Companion.configure do |config|
        config.app :server do |app|
          app.command = %(ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", ENV.fetch("PORT")); loop { server.accept.close }')
        end
      end
      Companion[:server].start

      get "/companion/apps/server"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<h1>server</h1>")
      expect(response.body).to match(%r{<td id="cpu">\d+\.\d%</td>})
      expect(response.body).to match(%r{<td id="memory">[\d.]+ [KMG]B \(\d+\.\d%\)</td>})
      expect(response.body).to include(%(<tr id="process_#{Companion[:server].pid}">))
      expect(response.body).to include(Companion[:server].url)
    end

    it "renders a stopped app without resource usage" do
      Companion.configure do |config|
        config.app :idle do |app|
          app.command = "true"
        end
      end

      get "/companion/apps/idle"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The app is not running.")
      expect(response.body).not_to include(%(<section id="processes">))
    end

    it "filters sensitive environment variables" do
      Companion.configure do |config|
        config.app :idle do |app|
          app.command = "true"
          app.environment = { RAILS_ENV: "development", SECRET_KEY_BASE: "hunter2", UNSET: nil }
        end
      end

      get "/companion/apps/idle"

      expect(response.body).to include("<code>development</code>")
      expect(response.body).to include("<code>[FILTERED]</code>")
      expect(response.body).to include("<code>(unset)</code>")
      expect(response.body).not_to include("hunter2")
    end

    it "responds with not found for an unknown app" do
      get "/companion/apps/missing"

      expect(response).to have_http_status(:not_found)
    end
  end
end
