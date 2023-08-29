# frozen_string_literal: true

require "abstract_notifier/version"

# Abstract Notifier is responsible for generating and triggering text-based notifications
# (like Action Mailer for email notifications).
#
# Example:
#
#   class ApplicationNotifier < AbstractNotifier::Base
#     self.driver = NotifyService.new
#
#     def profile
#       params[:profile] if params
#     end
#   end
#
#   class EventsNotifier < ApplicationNotifier
#     def canceled(event)
#       notification(
#         # the only required option is `body`
#         body: "Event #{event.title} has been canceled",
#         # all other options are passed to delivery driver
#         identity: profile.notification_service_id
#       )
#    end
#   end
#
#   EventsNotifier.with(profile: profile).canceled(event).notify_later
#
module AbstractNotifier
  DELIVERY_MODES = %i[test noop normal].freeze

  class << self
    attr_reader :delivery_mode
    attr_reader :async_adapter

    def delivery_mode=(val)
      unless DELIVERY_MODES.include?(val)
        raise ArgumentError, "Unsupported delivery mode: #{val}. " \
                             "Supported values: #{DELIVERY_MODES.join(", ")}"
      end

      @delivery_mode = val
    end

    def async_adapter=(args)
      adapter, options = Array(args)
      @async_adapter = AsyncAdapters.lookup(adapter, options)
    end

    def noop?
      delivery_mode == :noop
    end

    def test?
      delivery_mode == :test
    end
  end

  self.delivery_mode =
    if ENV["RACK_ENV"] == "test" || ENV["RAILS_ENV"] == "test"
      :test
    else
      :normal
    end
end

require "abstract_notifier/base"
require "abstract_notifier/async_adapters"

require "abstract_notifier/callbacks" if defined?(ActiveSupport)
require "abstract_notifier/async_adapters/active_job" if defined?(ActiveJob)

require "abstract_notifier/testing" if ENV["RACK_ENV"] == "test" || ENV["RAILS_ENV"] == "test"
