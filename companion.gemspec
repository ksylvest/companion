# frozen_string_literal: true

require_relative "lib/companion/version"

Gem::Specification.new do |spec|
  spec.name        = "companion"
  spec.version     = Companion::VERSION
  spec.authors     = ["Kevin Sylvestre"]
  spec.email       = ["kevin@ksylvest.com"]
  spec.homepage    = "https://github.com/ksylvest/companion"
  spec.summary     = "Spawn companion apps and proxy traffic to them."
  spec.description = "Companion is a mountable engine that spawns and supervises companion applications."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "http"
  spec.add_dependency "rails"
end
