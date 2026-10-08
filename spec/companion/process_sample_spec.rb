# frozen_string_literal: true

require "rails_helper"

RSpec.describe Companion::ProcessSample do
  describe ".capture" do
    it "samples every process in the group, leader first" do
      pid = Process.spawn("sleep 30 & sleep 30 & wait", pgroup: true)

      sample = nil
      Timeout.timeout(5) do
        sleep 0.05 until (sample = described_class.capture(pid)) && sample.entries.size == 3
      end

      expect(sample.entries.first.pid).to eq(pid)
      expect(sample.entries.drop(1).map(&:ppid)).to all(eq(pid))
      expect(sample.entries.drop(1).map(&:command)).to all(eq("sleep 30"))
      expect(sample.rss).to eq(sample.entries.sum(&:rss))
      expect(sample.rss).to be_positive
      expect(sample.cpu).to be >= 0
      expect(sample.memory).to be >= 0
      expect(sample.sampled_at).to be_within(5).of(Time.current)
    ensure
      Process.kill("TERM", -pid)
      Process.wait(pid)
    end

    it "returns nil when no process is in the group" do
      pid = Process.spawn("true")
      Process.wait(pid)

      expect(described_class.capture(pid)).to be_nil
    end

    it "returns nil when ps is unavailable" do
      allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)

      expect(described_class.capture(Process.pid)).to be_nil
    end
  end
end
