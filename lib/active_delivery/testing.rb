# frozen_string_literal: true

module ActiveDelivery
  module TestDelivery
    class << self
      def enable
        raise ArgumentError, "block is reauired" unless block_given?
        begin
          clear
          Thread.current[:active_delivery_testing] = true
          yield
        ensure
          Thread.current[:active_delivery_testing] = false
        end
      end

      def enabled?
        Thread.current[:active_delivery_testing] == true
      end

      def track(delivery, event, args, options)
        store << [delivery, event, args, options]
      end

      def store
        @store ||= []
      end

      def clear
        store.clear
      end
    end

    def notify(event, *args, **options)
      return super unless test?
      TestDelivery.track(self, event, args, options)
      nil
    end

    def test?
      TestDelivery.enabled?
    end
  end
end

ActiveDelivery::Base.prepend ActiveDelivery::TestDelivery

require "active_delivery/testing/rspec" if defined?(RSpec)
