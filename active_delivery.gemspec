# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "active_delivery/version"

Gem::Specification.new do |spec|
  spec.name = "active_delivery"
  spec.version = ActiveDelivery::VERSION
  spec.authors = ["Vladimir Dementyev"]
  spec.email = ["dementiev.vm@gmail.com"]

  spec.summary = "Rails framework for managing all types of notifications in one place"
  spec.description = "Rails framework for managing all types of notifications in one place"
  spec.homepage = "https://github.com/palkan/active_delivery"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 2.5"

  spec.metadata = {
    "bug_tracker_uri" => "http://github.com/palkan/active_delivery/issues",
    "changelog_uri" => "https://github.com/palkan/active_delivery/blob/master/CHANGELOG.md",
    "documentation_uri" => "http://github.com/palkan/active_delivery",
    "homepage_uri" => "http://github.com/palkan/active_delivery",
    "source_code_uri" => "http://github.com/palkan/active_delivery"
  }

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.16"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standard", "~> 0.2.0"
end
