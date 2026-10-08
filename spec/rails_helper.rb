# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require_relative "support/companion_helpers"

RSpec.configure do |config|
  config.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include CompanionHelpers

  config.after do
    companion_apps.each(&:stop)
    Companion.reset!
  end
end
