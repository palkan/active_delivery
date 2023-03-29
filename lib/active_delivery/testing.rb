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

      def store
        @store ||= []
      end

      def clear
        store.clear
      end
    end

    def perform_notify(delivery, **options)
      return super unless test?
      TestDelivery.track(delivery, options)
      nil
    end

    def test?
      TestDelivery.enabled?
    end
  end
end

ActiveDelivery::Base.prepend ActiveDelivery::TestDelivery

require "active_delivery/testing/rspec" if defined?(RSpec::Core)
