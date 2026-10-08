# frozen_string_literal: true

require "socket"
require "timeout"

module Companion
  # A companion web process that is booted on demand on a random local port
  # and stopped when the host application exits.
  class App
    # The interface companion apps bind to unless {#host} is set.
    DEFAULT_HOST = "127.0.0.1"

    # Wildcard bind addresses mapped to the loopback address used to reach them.
    WILDCARD_HOSTS = { "0.0.0.0" => "127.0.0.1", "::" => "::1" }.freeze

    # @return [Symbol] the name the app is registered under
    attr_reader :name

    # @return [Integer, nil] the port the app is listening on, or nil when stopped
    attr_reader :port

    # @return [Integer, nil] the process group leader's pid, or nil when stopped
    attr_reader :pid

    # @return [ActiveSupport::TimeWithZone, nil] when the app finished booting, or nil when stopped
    attr_reader :started_at

    # @return [String, #call, nil] the shell command to run, or a callable that
    #   receives the assigned port and returns one
    attr_accessor :command

    # @return [String, Pathname, nil] the working directory for the process;
    #   defaults to the current directory
    attr_accessor :directory

    # @return [Hash] extra environment variables for the process
    attr_accessor :environment

    # @return [Numeric] seconds to wait for the app to accept connections
    attr_accessor :boot_timeout

    # @return [String] the interface the app binds to, passed to the process as +HOST+;
    #   defaults to {DEFAULT_HOST}
    attr_accessor :host

    # @param name [Symbol] the name to register the app under
    def initialize(name)
      @name = name
      @host = DEFAULT_HOST
      @environment = {}
      @boot_timeout = 30
      @mutex = Mutex.new
    end

    # Checks that the app has everything it needs to boot.
    #
    # @raise [ConfigurationError] if no command is set
    # @return [void]
    def validate!
      raise ConfigurationError, "app #{name.inspect} requires a command" if command.nil?
    end

    # @return [String, nil] the base URL of the running app, or nil when stopped
    def url
      return unless port

      address = connect_host
      address = "[#{address}]" if address.include?(":")
      "http://#{address}:#{port}"
    end

    # Reports whether the spawned process is still alive.
    #
    # @return [Boolean]
    def running?
      return false unless @pid

      Process.waitpid(@pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      false
    end

    # @return [Symbol] +:running+ or +:stopped+
    def status
      running? ? :running : :stopped
    end

    # Spawns the app on a free port and blocks until it accepts connections.
    # Does nothing if the app is already running.
    #
    # @raise [BootError] if the process exits or does not listen within {#boot_timeout}
    # @return [void]
    def start
      @mutex.synchronize do
        return if running?

        @port = available_port
        @pid = Process.spawn(spawn_environment, resolved_command, chdir: String(directory || Dir.pwd), pgroup: true)
        wait_until_listening
        @started_at = Time.current
      end
    end

    # Sends TERM to the app's process group and waits for it to exit.
    # Does nothing if the app was never started.
    #
    # @return [void]
    def stop
      @mutex.synchronize do
        return unless @pid

        begin
          Process.kill("TERM", -@pid)
          Process.wait(@pid)
        rescue Errno::ESRCH, Errno::ECHILD
          # Already gone.
        end
        @pid = @port = @started_at = nil
      end
    end

    # Samples the CPU and memory usage of the app's process group.
    #
    # @return [ProcessSample, nil] nil when stopped or if sampling is unavailable
    def sample
      ProcessSample.capture(@pid) if running?
    end

    # @return [Proxy] a memoized Rack endpoint that forwards requests to this app
    def proxy
      @proxy ||= Proxy.new(self)
    end

  private

    # @return [String] the command to spawn, with callables invoked with the assigned port
    def resolved_command
      command.respond_to?(:call) ? command.call(@port) : String(command)
    end

    # @return [Hash{String => String, nil}] the configured environment with string keys and +HOST+ and +PORT+ set
    def spawn_environment
      environment.to_h { |key, value| [String(key), (String(value) unless value.nil?)] }
        .merge("HOST" => String(host), "PORT" => String(@port))
    end

    # @return [String] the address to connect to the app on, with wildcard hosts mapped to loopback
    def connect_host
      WILDCARD_HOSTS.fetch(String(host), String(host))
    end

    # Asks the OS for an unused port by briefly binding to port 0.
    #
    # @return [Integer]
    def available_port
      server = TCPServer.new(String(host), 0)
      server.addr[1]
    ensure
      server&.close
    end

    # Polls the app's port until it accepts a connection.
    #
    # @raise [BootError] if the process exits or the timeout elapses first
    # @return [void]
    def wait_until_listening
      Timeout.timeout(boot_timeout) do
        loop do
          raise BootError, "app #{name.inspect} exited during boot" unless running?

          TCPSocket.new(connect_host, @port).close
          break
        rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise BootError, "app #{name.inspect} did not listen on port #{@port} within #{boot_timeout}s"
    end
  end
end
