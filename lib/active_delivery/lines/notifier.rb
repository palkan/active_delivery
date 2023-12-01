# frozen_string_literal: true

unless "".respond_to?(:safe_constantize)
  require "active_delivery/ext/string_constantize"
  using ActiveDelivery::Ext::StringConstantize
end

module ActiveDelivery
  module Lines
    # AbstractNotifier line for Active Delivery.
    #
    # You must provide custom `resolver` to infer notifier class
    # (if String#safe_constantize is defined, we convert "*Delivery" -> "*Notifier").
    #
    # Resolver is a callable object.
    class Notifier < ActiveDelivery::Lines::Base
      DEFAULT_SUFFIX = "Notifier"

      def initialize(**opts)
        super
        @resolver ||= build_resolver(options.fetch(:suffix, DEFAULT_SUFFIX))
      end

      def resolve_class(klass)
        resolver&.call(klass)
      end

      def notify?(method_name)
        return unless handler_class
        handler_class.action_methods.include?(method_name.to_s)
      end

      def notify_now(handler, mid, *args)
        handler.public_send(mid, *args).notify_now
      end

      def notify_later(handler, mid, *args)
        handler.public_send(mid, *args).notify_later
      end

      def notify_later_with_options(handler, enqueue_options, mid, *args)
        handler.public_send(mid, *args).notify_later(**enqueue_options)
      end

      private

      attr_reader :resolver

      def build_resolver(suffix)
        lambda do |klass|
          klass_name = klass.name
          klass_name&.sub(/Delivery\z/, suffix)&.safe_constantize
        end
      end
    end
  end
end
