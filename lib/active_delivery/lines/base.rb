# frozen_string_literal: true

module ActiveDelivery
  module Lines
    class Base
      attr_reader :id, :options
      attr_accessor :owner
      attr_writer :handler_class

      DEFAULT_RESOLVER = ->(name) { name.gsub(/Delivery$/, "Notifier").safe_constantize }

      def initialize(id:, owner:, **options)
        @id = id
        @owner = owner
        @options = options.tap(&:freeze)
        @resolver = options[:resolver]
      end

      def dup_for(new_owner)
        self.class.new(id: id, **options, owner: new_owner)
      end

      def resolve_class(name)
        resolver&.call(name)
      end

      def notify?(method_name)
        handler_class.respond_to?(method_name)
      end

      def notify_now(handler, mid, *args, **kwargs)
      end

      def notify_later(handler, mid, *args, **kwargs)
      end

      def notify(mid, *args, params:, sync:, **kwargs)
        clazz = params.empty? ? handler_class : handler_class.with(**params)
        sync ? notify_now(clazz, mid, *args, **kwargs) : notify_later(clazz, mid, *args, **kwargs)
      end

      def handler_class
        return @handler_class if instance_variable_defined?(:@handler_class)

        return @handler_class = nil if owner.abstract_class?

        @handler_class = resolve_class(owner.name) ||
          superclass_handler
      end

      private

      def superclass_handler
        handler_method = "#{id}_class"

        return if ActiveDelivery::Base == owner.superclass
        return unless owner.superclass.respond_to?(handler_method)

        owner.superclass.public_send(handler_method)
      end

      attr_reader :resolver
    end
  end
end
