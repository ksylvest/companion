# frozen_string_literal: true

require "rails_helper"
require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe Companion::App do
  describe "#initialize" do
    it "stores the name and defaults" do
      app = described_class.new(:dashboard)

      expect(app.name).to eq(:dashboard)
      expect(app.command).to be_nil
      expect(app.directory).to be_nil
      expect(app.environment).to eq({})
      expect(app.boot_timeout).to eq(30)
      expect(app.host).to eq("127.0.0.1")
      expect(app.port).to be_nil
      expect(app.pid).to be_nil
      expect(app.started_at).to be_nil
      expect(app.url).to be_nil
      expect(app.running?).to be(false)
      expect(app.status).to eq(:stopped)
    end
  end

  describe "#validate!" do
    it "requires a command" do
      app = described_class.new(:dashboard)

      expect { app.validate! }.to raise_error(Companion::ConfigurationError, "app :dashboard requires a command")

      app.command = "true"
      app.validate!
    end
  end

  describe "#sample" do
    it "returns nil when stopped" do
      expect(described_class.new(:dashboard).sample).to be_nil
    end

    it "samples the process group of a running app" do
      app = build_app
      app.start

      sample = app.sample

      expect(sample).to be_a(Companion::ProcessSample)
      expect(sample.entries.first.pid).to eq(app.pid)
    end
  end

  describe "#proxy" do
    it "returns a memoized proxy for the app" do
      app = described_class.new(:dashboard)

      expect(app.proxy).to be_a(Companion::Proxy)
      expect(app.proxy).to equal(app.proxy)
    end
  end

  describe "#start" do
    it "spawns a callable command with the assigned port, directory, and environment" do
      directory = nil
      previous_unset = ENV["UNSET_ME"]
      directory = Pathname(Dir.mktmpdir)
      seen_port = nil
      ENV["UNSET_ME"] = "parent"

      app = build_app(
        directory: directory,
        environment: { "PORT" => "1", "WORKERS" => 2, "COMPANION_SPEC_MODE" => "production", "UNSET_ME" => nil },
        command: ->(port) do
          seen_port = port
          server_command(port)
        end,
      )

      expect(app.url).to be_nil

      app.start
      payload = fetch_payload(app)

      expect(app.url).to eq("http://127.0.0.1:#{app.port}")
      expect(app.status).to eq(:running)
      expect(app.started_at).to be_within(2.seconds).of(Time.zone.now)
      expect(seen_port).to eq(app.port)
      expect(File.realpath(payload["pwd"])).to eq(String(directory.realpath))
      expect(payload["env"]).to eq(
        "HOST" => "127.0.0.1",
        "PORT" => String(app.port),
        "WORKERS" => "2",
        "COMPANION_SPEC_MODE" => "production",
        "UNSET_ME" => nil,
      )

      port = app.port
      pid = app.pid
      app.start

      expect(app.port).to eq(port)
      expect(app.pid).to eq(pid)
    ensure
      if previous_unset.nil?
        ENV.delete("UNSET_ME")
      else
        ENV["UNSET_ME"] = previous_unset
      end
      FileUtils.remove_entry(directory) if directory
    end

    it "passes the assigned port to a string command through PORT" do
      app = build_app(command: :server_string, environment: { "PORT" => "1" })

      app.start

      expect(fetch_payload(app).dig("env", "PORT")).to eq(String(app.port))
    end

    it "binds to a custom host and passes it through HOST" do
      app = build_app(host: "0.0.0.0", environment: { "HOST" => "example.com" })

      app.start

      expect(app.url).to eq("http://127.0.0.1:#{app.port}")
      expect(fetch_payload(app).dig("env", "HOST")).to eq("0.0.0.0")
    end

    it "brackets IPv6 hosts in the URL" do
      app = build_app(host: "::1")

      app.start

      expect(app.url).to eq("http://[::1]:#{app.port}")
      expect(fetch_payload(app).dig("env", "HOST")).to eq("::1")
    end

    it "starts once when called concurrently" do
      app = build_app
      threads = Array.new(2) { Thread.new { app.start } }
      threads.each(&:join)

      expect(app.running?).to be(true)
      expect(app.port).to be_a(Integer)
    end

    it "raises when the process exits before listening" do
      app = build_app(:exited, command: [ RbConfig.ruby, "-e", "exit 1" ].shelljoin, boot_timeout: 2)

      expect { app.start }.to raise_error(Companion::BootError, "app :exited exited during boot")
    end

    it "raises when the process does not listen before the boot timeout" do
      app = build_app(:sleeper, command: [ RbConfig.ruby, "-e", "sleep 30" ].shelljoin, boot_timeout: 0.5)

      expect { app.start }.to raise_error(Companion::BootError, /app :sleeper did not listen on port \d+ within 0\.5s/)
      expect(app.pid).to be_a(Integer)
      expect(app.started_at).to be_nil
    end
  end

  describe "#running?" do
    it "is false once the process has exited" do
      app = build_app
      app.start
      pid = app.pid

      Process.kill("TERM", pid)
      Process.wait(pid)

      expect(app.running?).to be(false)
      expect(app.running?).to be(false)
      expect(app.status).to eq(:stopped)
      expect(app.pid).to eq(pid)
    end
  end

  describe "#stop" do
    it "is safe to call before start and again after stop" do
      app = build_app
      app.stop

      app.start
      app.stop
      app.stop

      expect(app.running?).to be(false)
      expect(app.status).to eq(:stopped)
      expect(app.port).to be_nil
      expect(app.pid).to be_nil
      expect(app.started_at).to be_nil
      expect(app.url).to be_nil
    end

    it "can start again after stopping" do
      app = build_app
      app.start
      first_pid = app.pid

      app.stop
      app.start

      expect(app.running?).to be(true)
      expect(app.pid).not_to eq(first_pid)
      expect(app.started_at).to be_within(2.seconds).of(Time.zone.now)
    end
  end
end
