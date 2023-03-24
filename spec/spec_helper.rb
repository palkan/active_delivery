# frozen_string_literal: true

ENV["RACK_ENV"] = "test"

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

require "ruby-next/language/runtime"

if ENV["CI"] == "true"
  # Only transpile specs, source code MUST be loaded from pre-transpiled files
  RubyNext::Language.watch_dirs.clear
  RubyNext::Language.watch_dirs << __dir__
end

unless ENV["NO_RAILS"]
  require "action_mailer"
  require "active_job"
  ActiveJob::Base.queue_adapter = :test
  ActiveJob::Base.logger = Logger.new(IO::NULL)
end

require "active_delivery"

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.order = :random

  config.example_status_persistence_file_path = "tmp/.rspec_status"

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
