# frozen_string_literal: true

require "json"
require "socket"

# Accepts one HTTP request at a time and echoes it back as JSON.
# /multi returns multiple response header values instead.
class TestHttpServer
  def initialize(host, port)
    @host = host
    @port = port
  end

  def start
    server = TCPServer.new(@host, @port)

    loop do
      socket = server.accept
      begin
        serve(socket)
      rescue IOError, SystemCallError
        next
      ensure
        socket.close unless socket.closed?
      end
    end
  end

  private

  def serve(socket)
    raw = read_headers(socket)
    return if raw.empty?

    method, target, = raw.lines.first.split
    headers = parse_headers(raw)
    body = read_body(socket, headers)
    path = String(target).split("?", 2).first

    if path == "/multi"
      write_response(socket, "201 Created", multi_headers(method), "ok")
    else
      write_response(
        socket,
        "200 OK",
        json_headers(method),
        JSON.generate(payload(method, target, body, headers)),
      )
    end
  end

  def read_headers(socket)
    raw = +""
    while (line = socket.gets)
      raw << line
      break if line == "\r\n" || line == "\n"
    end
    raw
  end

  def parse_headers(raw)
    raw.lines.drop(1).each_with_object({}) do |line, headers|
      key, value = line.split(": ", 2)
      next unless key && value

      headers[key.downcase] = value.strip
    end
  end

  def read_body(socket, headers)
    if headers["content-length"]
      String(socket.read(headers["content-length"].to_i))
    elsif String(headers["transfer-encoding"]).include?("chunked")
      read_chunked(socket)
    else
      ""
    end
  end

  def read_chunked(socket)
    body = +""
    loop do
      size = String(socket.gets).strip.split(";", 2).first.to_i(16)
      break if size.zero?

      body << String(socket.read(size))
      socket.gets
    end
    socket.gets
    body
  end

  def payload(method, target, body, headers)
    {
      method: method,
      target: target,
      body: body,
      headers: headers,
      pwd: Dir.pwd,
      env: {
        HOST: ENV["HOST"],
        PORT: ENV["PORT"],
        WORKERS: ENV["WORKERS"],
        COMPANION_SPEC_MODE: ENV["COMPANION_SPEC_MODE"],
        UNSET_ME: ENV["UNSET_ME"],
      },
    }
  end

  def json_headers(method)
    {
      "content-type" => "application/json",
      "x-custom" => "from-app",
      "x-method" => method,
    }
  end

  def multi_headers(method)
    {
      "content-type" => "text/plain",
      "set-cookie" => [ "a=1", "b=2" ],
      "proxy-authenticate" => "Basic",
      "x-method" => method,
    }
  end

  def write_response(socket, status, headers, body)
    lines = [ "HTTP/1.1 #{status}" ]
    headers.each do |key, value|
      Array(value).each { |item| lines << "#{key}: #{item}" }
    end
    lines << "content-length: #{body.bytesize}"
    lines << "connection: close"
    socket.write("#{lines.join("\r\n")}\r\n\r\n")
    socket.write(body)
  end
end

TestHttpServer.new(ENV.fetch("HOST", "127.0.0.1"), Integer(ARGV[0] || ENV.fetch("PORT"))).start
