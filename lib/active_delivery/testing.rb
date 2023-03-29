# frozen_string_literal: true

module ActiveDelivery
  module TestDelivery
    class << self
      def enable
        raise ArgumentError, "block is required" unless block_given?
        begin
          clear
          Thread.current.thread_variable_set(:active_delivery_testing, true)
          yield
        ensure
          Thread.current.thread_variable_set(:active_delivery_testing, false)
        end
      end

      def enabled?
        Thread.current.thread_variable_get(:active_delivery_testing) == true
      end

      def track(delivery, options)
        store << [delivery, options]
      end

      def track_line(line)
        lines << line
      end

      def store
        Thread.current.thread_variable_get(:active_delivery_testing_store) || Thread.current.thread_variable_set(:active_delivery_testing_store, [])
      end

      def lines
        Thread.current.thread_variable_get(:active_delivery_testing_lines) || Thread.current.thread_variable_set(:active_delivery_testing_lines, [])
      end

      def clear
        store.clear
        lines.clear
      end
    end

    def perform_notify(delivery, **options)
      return super unless test?
      TestDelivery.track(delivery, options)
      nil
    end

    def notify_line(line, ...)
      res = super
      TestDelivery.track_line(line) if res
    end

    def test?
      TestDelivery.enabled?
    end
  end
end

ActiveDelivery::Base.prepend ActiveDelivery::TestDelivery

require "active_delivery/testing/rspec" if defined?(RSpec::Core)
