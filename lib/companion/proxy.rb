# frozen_string_literal: true

require "http"

module Companion
  # A Rack endpoint that boots an {App} on first use and forwards requests to it.
  class Proxy
    # Connection-scoped headers that must not be forwarded between hops (RFC 9110 §7.6.1).
    HOP_BY_HOP_HEADERS = %w[
      connection keep-alive proxy-authenticate proxy-authorization
      te trailer transfer-encoding upgrade
    ].freeze

    # @param app [App] the app to forward requests to
    def initialize(app)
      @app = app
    end

    # Forwards a Rack request to the app, starting it if needed.
    #
    # @param env [Hash] the Rack environment
    # @return [Array(Integer, Hash, Array<String>)] a Rack response; 502 if the
    #   app fails to boot or the upstream request fails
    def call(env)
      @app.start unless @app.running?

      request = Rack::Request.new(env)
      body = request_body(request)
      headers = request_headers(request)
      headers["transfer-encoding"] = "chunked" if body && !request.content_length

      response = HTTP.request(request.request_method.downcase.to_sym, url(request), headers:, body:)

      [response.code, response_headers(response), [String(response)]]
    rescue BootError, HTTP::Error, SystemCallError => e
      [502, { "content-type" => "text/plain" }, ["Bad Gateway: #{e.message}"]]
    end

  private

    # @param request [Rack::Request]
    # @return [String] the upstream URL for the request's path and query string
    def url(request)
      path = request.path_info.presence || "/"
      path += "?#{request.query_string}" if request.query_string.present?

      "#{@app.url}#{path}"
    end

    # @param request [Rack::Request]
    # @return [IO, nil] the request body stream, or nil when the request has no body
    def request_body(request)
      request.body if request.content_length.to_i.positive? || request.get_header("HTTP_TRANSFER_ENCODING")
    end

    # Builds the upstream request headers, dropping hop-by-hop headers and
    # adding the standard +X-Forwarded-*+ headers.
    #
    # @param request [Rack::Request]
    # @return [Hash{String => String}]
    def request_headers(request)
      headers = {}
      request.each_header do |key, value|
        next unless key.start_with?("HTTP_")

        name = key.delete_prefix("HTTP_").downcase.tr("_", "-")
        headers[name] = value unless HOP_BY_HOP_HEADERS.include?(name)
      end
      headers["content-type"] = request.content_type if request.content_type
      headers["content-length"] = request.content_length if request.content_length
      headers["x-forwarded-for"] = [headers["x-forwarded-for"], request.ip].compact.join(", ")
      headers["x-forwarded-host"] = request.host_with_port
      headers["x-forwarded-proto"] = request.scheme
      headers["x-forwarded-prefix"] = request.script_name if request.script_name.present?
      headers
    end

    # Converts upstream headers to Rack headers, dropping hop-by-hop headers and
    # +content-length+ (the body is re-buffered). Repeated headers become arrays.
    #
    # @param response [HTTP::Response]
    # @return [Hash{String => String, Array<String>}]
    def response_headers(response)
      headers = {}
      response.headers.each do |key, value|
        name = key.downcase
        next if HOP_BY_HOP_HEADERS.include?(name) || name == "content-length"

        headers[name] = headers.key?(name) ? [*headers[name], value] : value
      end
      headers
    end
  end
end
