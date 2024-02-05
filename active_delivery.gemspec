# frozen_string_literal: true

require_relative "lib/active_delivery/version"

Gem::Specification.new do |s|
  s.name = "active_delivery"
  s.version = ActiveDelivery::VERSION
  s.authors = ["Vladimir Dementyev"]
  s.email = ["Vladimir Dementyev"]
  s.homepage = "https://github.com/palkan/active_delivery"
  s.summary = "Ruby and Rails framework for managing all types of notifications in one place"
  s.description = "Ruby and Rails framework for managing all types of notifications in one place"

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/palkan/active_delivery/issues",
    "changelog_uri" => "https://github.com/palkan/active_delivery/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/palkan/active_delivery",
    "homepage_uri" => "https://github.com/palkan/active_delivery",
    "source_code_uri" => "https://github.com/palkan/active_delivery"
  }

  s.license = "MIT"

  s.files = Dir.glob("lib/**/*") + Dir.glob("lib/.rbnext/**/*") + Dir.glob("bin/**/*") + %w[README.md LICENSE.txt CHANGELOG.md]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 2.7"

  s.add_development_dependency "bundler", ">= 1.15"
  s.add_development_dependency "rake", ">= 13.0"
  s.add_development_dependency "rspec", ">= 3.9"
  s.add_development_dependency "rspec-rails", ">= 4.0"

  # When gem is installed from source, we add `ruby-next` as a dependency
  # to auto-transpile source files during the first load
  if ENV["RELEASING_GEM"].nil? && File.directory?(File.join(__dir__, ".git"))
    s.add_runtime_dependency "ruby-next", "~> 1.0"
  else
    s.add_dependency "ruby-next-core", "~> 1.0"
  end
end
