# frozen_string_literal: true

require "json"
require "net/http"
require "rbconfig"
require "shellwords"
require "stringio"
require "uri"

module CompanionHelpers
  def companion_apps
    @companion_apps ||= []
  end

  def build_app(name = :dashboard, command: :server, directory: nil, environment: {}, boot_timeout: 5, host: nil)
    app = Companion::App.new(name)
    app.command = command_for(command)
    app.host = host unless host.nil?
    app.directory = directory unless directory.nil?
    app.environment = environment
    app.boot_timeout = boot_timeout
    companion_apps << app
    app
  end

  def server_command(port = nil)
    arguments = [ RbConfig.ruby, http_server_path ]
    arguments << String(port) if port
    arguments.shelljoin
  end

  def http_server_path
    File.expand_path("http_server.rb", __dir__)
  end

  def rack_env(overrides = {})
    {
      "REQUEST_METHOD" => "GET",
      "SCRIPT_NAME" => "",
      "PATH_INFO" => "/",
      "QUERY_STRING" => "",
      "SERVER_NAME" => "example.com",
      "SERVER_PORT" => "3000",
      "HTTP_HOST" => "example.com:3000",
      "rack.url_scheme" => "http",
      "rack.input" => StringIO.new(""),
      "REMOTE_ADDR" => "203.0.113.5",
    }.merge(overrides)
  end

  def fetch_payload(app, path = "/")
    JSON.parse(Net::HTTP.get(URI("#{app.url}#{path}")))
  end

  private

  def command_for(command)
    case command
    when :server
      ->(port) { server_command(port) }
    when :server_string
      server_command
    else
      command
    end
  end
end
