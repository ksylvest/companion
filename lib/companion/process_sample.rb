# frozen_string_literal: true

require "open3"

module Companion
  # A point-in-time snapshot of the resource usage of every process in an
  # app's process group, read from +ps+.
  class ProcessSample
    # A single process in the sampled group.
    #
    # @!attribute pid [Integer]
    # @!attribute ppid [Integer] the parent's pid
    # @!attribute cpu [Float] CPU usage as a percentage of one core, as reported by +ps+
    # @!attribute memory [Float] resident memory as a percentage of physical memory
    # @!attribute rss [Integer] resident memory in bytes
    # @!attribute command [String]
    Entry = Data.define(:pid, :ppid, :cpu, :memory, :rss, :command)

    # Each column gets its own +-o+ flag so empty headers are not parsed as part of the next column.
    COLUMNS = %w[pid ppid pgid pcpu pmem rss command].freeze

    # Samples every process whose process group is led by +pgid+.
    #
    # @param pgid [Integer] the process group leader's pid
    # @return [ProcessSample, nil] nil if +ps+ is unavailable or no process is in the group
    def self.capture(pgid)
      output, status = Open3.capture2("ps", "-A", "-ww", *COLUMNS.flat_map { |column| ["-o", "#{column}="] })
      return unless status.success?

      entries = output.each_line.filter_map { |line| parse(line, pgid) }
      new(pgid, entries, Time.current) unless entries.empty?
    rescue SystemCallError
      nil
    end

    # @param line [String] a row of +ps+ output
    # @param pgid [Integer]
    # @return [Entry, nil] nil unless the row belongs to the process group
    def self.parse(line, pgid)
      pid, ppid, group, cpu, memory, rss, command = line.strip.split(/\s+/, COLUMNS.size)
      return unless Integer(group, exception: false) == pgid

      Entry.new(pid: Integer(pid), ppid: Integer(ppid), cpu: Float(cpu), memory: Float(memory),
        rss: Integer(rss) * 1024, command: String(command))
    end
    private_class_method :parse

    # @return [Array<Entry>] the processes in the group, leader first
    attr_reader :entries

    # @return [ActiveSupport::TimeWithZone] when the sample was taken
    attr_reader :sampled_at

    # @param pgid [Integer] the process group leader's pid
    # @param entries [Array<Entry>]
    # @param sampled_at [ActiveSupport::TimeWithZone]
    def initialize(pgid, entries, sampled_at)
      @entries = entries.sort_by { |entry| [entry.pid == pgid ? 0 : 1, entry.pid] }
      @sampled_at = sampled_at
    end

    # @return [Float] combined CPU usage across the group, as a percentage of one core
    def cpu
      entries.sum(&:cpu)
    end

    # @return [Float] combined resident memory as a percentage of physical memory
    def memory
      entries.sum(&:memory)
    end

    # @return [Integer] combined resident memory in bytes
    def rss
      entries.sum(&:rss)
    end
  end
end
