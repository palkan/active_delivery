# frozen_string_literal: true

ENV["RACK_ENV"] = "test"

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

require "ruby-next/language/runtime"

if ENV["CI"] == "true"
  # Only transpile specs, source code MUST be loaded from pre-transpiled files
  RubyNext::Language.include_patterns.clear
  RubyNext::Language.include_patterns << File.join(__dir__, "*.rb")
end

unless ENV["NO_RAILS"]
  require "rails"
  require "action_controller/railtie"
  require "action_mailer/railtie"
  require "active_job/railtie"
  require "rspec/rails"

  ActiveJob::Base.queue_adapter = :test
  ActiveJob::Base.logger = Logger.new(IO::NULL)
end

require "active_delivery"

class TestJobAdapter
  attr_reader :jobs

  def initialize
    @jobs = []
  end

  def enqueue(notifier, action_name, params:, args:, kwargs:)
    jobs << [notifier, action_name, params, args, kwargs]
  end

  def clear
    @jobs.clear
  end
end

AbstractNotifier.async_adapter = TestJobAdapter.new

class TestDriver
  class << self
    def deliveries
      @deliveries ||= []
    end

    def call(payload)
      deliveries << payload
    end
  end
end

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

  config.after do
    AbstractNotifier.async_adapter.clear
    TestDriver.deliveries.clear
  end
end
