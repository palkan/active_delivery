module ActiveDelivery
  module Lines
    class Base
      attr_reader :id
      attr_accessor :owner
      attr_writer :handler_class

      def initialize(id, owner)
        @id = id
        @owner = owner
      end

      def dup_for(new_owner)
        self.class.new(id, new_owner)
      end

      def resolve_class(name)
      end

      def notify?(method_name)
        handler_class.respond_to?(method_name)
      end

      def notify_now(handler, mid, *args)
      end

      def notify_later(handler, mid, *args)
      end

      def notify(mid, *args, params:, sync:)
        clazz = params.empty? ? handler_class : handler_class.with(params)
        sync ? notify_now(clazz, mid, *args) : notify_later(clazz, mid, *args)
      end

      def handler_class
        return @handler_class if instance_variable_defined?(:@handler_class)

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
    end
  end
end
