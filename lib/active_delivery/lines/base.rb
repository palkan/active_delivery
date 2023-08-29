# frozen_string_literal: true

unless "".respond_to?(:safe_constantize)
  require "active_delivery/ext/string_constantize"
  using ActiveDelivery::Ext::StringConstantize
end

module ActiveDelivery
  module Lines
    class Base
      attr_reader :id, :options
      attr_accessor :owner
      attr_accessor :handler_class_name

      def initialize(id:, owner:, **options)
        @id = id
        @owner = owner
        @options = options.tap(&:freeze)
        @resolver = options[:resolver] || build_pattern_resolver(options[:resolver_pattern])
      end

      def dup_for(new_owner)
        self.class.new(id:, **options, owner: new_owner)
      end

      def resolve_class(name)
        resolver&.call(name)
      end

      def notify?(method_name)
        handler_class&.respond_to?(method_name)
      end

      def notify_now(handler, mid, ...)
      end

      def notify_later(handler, mid, ...)
      end

      def notify(mid, *args, params:, sync:, **kwargs)
        clazz = params.empty? ? handler_class : handler_class.with(**params)
        sync ? notify_now(clazz, mid, *args, **kwargs) : notify_later(clazz, mid, *args, **kwargs)
      end

      def handler_class
        if ::ActiveDelivery.cache_classes
          return @handler_class if instance_variable_defined?(:@handler_class)
        end

        return @handler_class = nil if owner.abstract_class?

        superline = owner.superclass.delivery_lines[id] if owner.superclass.respond_to?(:delivery_lines) && owner.superclass.delivery_lines[id]

        # If an explicit class name has been specified somewhere in the ancestor chain, use it.
        class_name = @handler_class_name || superline&.handler_class_name

        @handler_class =
          if class_name
            class_name.is_a?(Class) ? class_name : class_name.safe_constantize
          else
            resolve_class(owner) || superline&.handler_class
          end
      end

      private

      attr_reader :resolver

      def build_pattern_resolver(pattern)
        return unless pattern

        proc do |delivery|
          delivery_class = delivery.name

          next unless delivery_class

          *namespace, delivery_name = delivery_class.split("::")

          delivery_namespace = ""
          delivery_namespace = "#{namespace.join("::")}::" unless namespace.empty?

          delivery_name = delivery_name.sub(/Delivery$/, "")

          (pattern % {delivery_class:, delivery_name:, delivery_namespace:}).safe_constantize
        end
      end
    end
  end
end
