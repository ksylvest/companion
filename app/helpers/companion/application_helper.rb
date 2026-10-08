# frozen_string_literal: true

module Companion
  module ApplicationHelper
    def companion_command(app)
      app.command.respond_to?(:call) ? String(app.command.call("$PORT")) : String(app.command)
    end

    def companion_uptime(app)
      app.started_at ? time_ago_in_words(app.started_at) : "—"
    end

    def companion_directory(app)
      return "—" unless app.directory

      Pathname(app.directory).expand_path.relative_path_from(Rails.root).to_s
    end

    def companion_environment(app)
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      filter.filter(app.environment.to_h { |key, value| [String(key), value] })
    end

    def companion_cpu(value)
      number_to_percentage(value, precision: 1)
    end

    def companion_memory(rss, percentage)
      "#{number_to_human_size(rss)} (#{number_to_percentage(percentage, precision: 1)})"
    end
  end
end
