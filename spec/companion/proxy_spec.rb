# frozen_string_literal: true

require "rails_helper"

RSpec.describe Companion::Proxy do
  describe "#call" do
    it "starts the app and proxies the request" do
      app = build_app

      status, headers, body = app.proxy.call(rack_env)

      expect(status).to eq(200)
      expect(app.running?).to be(true)
      expect(headers).to eq(
        "content-type" => "application/json",
        "x-custom" => "from-app",
        "x-method" => "GET",
      )
      expect(JSON.parse(body.first)).to include("method" => "GET", "target" => "/")
    end

    it "normalizes a blank path and keeps the query string" do
      app = build_app

      _status, _headers, body = app.proxy.call(rack_env("PATH_INFO" => "", "QUERY_STRING" => "a=1"))

      expect(JSON.parse(body.first)["target"]).to eq("/?a=1")
    end

    it "forwards the method, target, body, and headers", :aggregate_failures do
      app = build_app
      env = rack_env(
        "REQUEST_METHOD" => "POST",
        "SCRIPT_NAME" => "/dashboard",
        "PATH_INFO" => "/submit",
        "QUERY_STRING" => "q=1",
        "HTTP_HOST" => "example.com:8443",
        "rack.url_scheme" => "https",
        "CONTENT_TYPE" => "text/plain",
        "CONTENT_LENGTH" => "5",
        "rack.input" => StringIO.new("hello"),
        "HTTP_ACCEPT" => "application/json",
        "HTTP_X_REQUEST_ID" => "abc",
        "HTTP_X_FORWARDED_FOR" => "198.51.100.9",
        "HTTP_CONNECTION" => "close",
        "HTTP_UPGRADE" => "websocket",
        "HTTP_TE" => "trailers",
        "HTTP_TRAILER" => "x-foo",
        "HTTP_PROXY_AUTHORIZATION" => "secret",
      )

      status, _headers, body = app.proxy.call(env)
      payload = JSON.parse(body.first)

      expect(status).to eq(200)
      expect(payload["method"]).to eq("POST")
      expect(payload["target"]).to eq("/submit?q=1")
      expect(payload["body"]).to eq("hello")
      expect(payload["headers"]).to include(
        "content-type" => "text/plain",
        "content-length" => "5",
        "accept" => "application/json",
        "x-request-id" => "abc",
      )
      expect(payload["headers"].slice("x-forwarded-for", "x-forwarded-host", "x-forwarded-proto", "x-forwarded-prefix")).to eq(
        "x-forwarded-for" => "198.51.100.9, 203.0.113.5",
        "x-forwarded-host" => "example.com:8443",
        "x-forwarded-proto" => "https",
        "x-forwarded-prefix" => "/dashboard",
      )
      expect(payload["headers"].slice("upgrade", "te", "trailer", "proxy-authorization")).to eq({})
    end

    it "sends the body and drops hop-by-hop transfer-encoding" do
      app = build_app
      env = rack_env(
        "REQUEST_METHOD" => "POST",
        "PATH_INFO" => "/upload",
        "CONTENT_LENGTH" => "5",
        "HTTP_TRANSFER_ENCODING" => "chunked",
        "rack.input" => StringIO.new("hello"),
      )

      _status, _headers, body = app.proxy.call(env)
      payload = JSON.parse(body.first)

      expect(payload["body"]).to eq("hello")
      expect(payload["headers"]).not_to have_key("transfer-encoding")
    end

    it "proxies a HEAD request without returning a body" do
      app = build_app

      status, headers, body = app.proxy.call(rack_env("REQUEST_METHOD" => "HEAD", "PATH_INFO" => "/health"))

      expect(status).to eq(200)
      expect(headers["x-method"]).to eq("HEAD")
      expect(body).to eq([ "" ])
    end

    it "keeps repeated response headers and drops hop-by-hop response headers" do
      app = build_app

      status, headers, body = app.proxy.call(rack_env("PATH_INFO" => "/multi"))

      expect(status).to eq(201)
      expect(body).to eq([ "ok" ])
      expect(headers).to eq(
        "content-type" => "text/plain",
        "set-cookie" => [ "a=1", "b=2" ],
        "x-method" => "GET",
      )
    end

    it "does not start an app that is already running" do
      app = build_app
      app.start
      expect(app).not_to receive(:start)

      status, = app.proxy.call(rack_env)

      expect(status).to eq(200)
    end

    it "returns 502 when the app fails to boot" do
      app = build_app(:dashboard, command: [ RbConfig.ruby, "-e", "exit 1" ].shelljoin, boot_timeout: 2)

      status, headers, body = app.proxy.call(rack_env)

      expect(status).to eq(502)
      expect(headers).to eq("content-type" => "text/plain")
      expect(body).to eq([ "Bad Gateway: app :dashboard exited during boot" ])
    end

    it "returns 502 when the upstream connection fails" do
      app = build_app
      app.start
      port = app.port
      app.stop
      allow(app).to receive_messages(running?: true, port: port)

      status, headers, body = app.proxy.call(rack_env)

      expect(status).to eq(502)
      expect(headers).to eq("content-type" => "text/plain")
      expect(body.first).to include("Bad Gateway:", "Connection refused")
    end
  end
end
