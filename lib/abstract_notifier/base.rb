# frozen_string_literal: true

module AbstractNotifier
  # NotificationDelivery payload wrapper which contains
  # information about the current notifier class
  # and knows how to trigger the delivery
  class NotificationDelivery
    attr_reader :action_name

    def initialize(owner_class, action_name, params: {}, args: [], kwargs: {})
      @owner_class = owner_class
      @action_name = action_name
      @params = params
      @args = args
      @kwargs = kwargs
    end

    def processed
      return @processed if instance_variable_defined?(:@processed)

      @processed = notifier.process_action(action_name, *args, **kwargs) || Notification.new(nil)
    end

    alias_method :notification, :processed

    def notify_later
      owner_class.async_adapter.enqueue(owner_class.name, action_name, params:, args:, kwargs:)
    end

    def notify_now
      return unless notification.payload

      notifier.deliver!(notification)
    end

    private

    attr_reader :owner_class, :params, :args, :kwargs

    def notifier
      @notifier ||= owner_class.new(action_name, **params)
    end
  end

  # Notification object contains the compiled payload to be delivered
  class Notification
    attr_reader :payload

    def initialize(payload)
      @payload = payload
    end
  end

  # Base class for notifiers
  class Base
    class ParamsProxy
      attr_reader :notifier_class, :params

      def initialize(notifier_class, params)
        @notifier_class = notifier_class
        @params = params
      end

      # rubocop:disable Style/MethodMissingSuper
      def method_missing(method_name, *args, **kwargs)
        NotificationDelivery.new(notifier_class, method_name, params:, args:, kwargs:)
      end
      # rubocop:enable Style/MethodMissingSuper

      def respond_to_missing?(*args)
        notifier_class.respond_to_missing?(*args)
      end
    end

    class << self
      attr_writer :driver

      def driver
        return @driver if instance_variable_defined?(:@driver)

        @driver =
          if superclass.respond_to?(:driver)
            superclass.driver
          else
            raise "Driver not found for #{name}. " \
                  "Please, specify driver via `self.driver = MyDriver`"
          end
      end

      def async_adapter=(args)
        adapter, options = Array(args)
        @async_adapter = AsyncAdapters.lookup(adapter, options)
      end

      def async_adapter
        return @async_adapter if instance_variable_defined?(:@async_adapter)

        @async_adapter =
          if superclass.respond_to?(:async_adapter)
            superclass.async_adapter
          else
            AbstractNotifier.async_adapter
          end
      end

      def default(method_name = nil, **hargs, &block)
        return @defaults_generator = block if block

        return @defaults_generator = proc { send(method_name) } unless method_name.nil?

        @default_params =
          if superclass.respond_to?(:default_params)
            superclass.default_params.merge(hargs).freeze
          else
            hargs.freeze
          end
      end

      def defaults_generator
        return @defaults_generator if instance_variable_defined?(:@defaults_generator)

        @defaults_generator =
          if superclass.respond_to?(:defaults_generator)
            superclass.defaults_generator
          end
      end

      def default_params
        return @default_params if instance_variable_defined?(:@default_params)

        @default_params =
          if superclass.respond_to?(:default_params)
            superclass.default_params.dup
          else
            {}
          end
      end

      def method_missing(method_name, *args, **kwargs)
        if action_methods.include?(method_name.to_s)
          NotificationDelivery.new(self, method_name, args:, kwargs:)
        else
          super
        end
      end

      def with(params)
        ParamsProxy.new(self, params)
      end

      def respond_to_missing?(method_name, _include_private = false)
        action_methods.include?(method_name.to_s) || super
      end

      # See https://github.com/rails/rails/blob/b13a5cb83ea00d6a3d71320fd276ca21049c2544/actionpack/lib/abstract_controller/base.rb#L74
      def action_methods
        @action_methods ||= begin
          # All public instance methods of this class, including ancestors
          methods = (public_instance_methods(true) -
            # Except for public instance methods of Base and its ancestors
            Base.public_instance_methods(true) +
            # Be sure to include shadowed public instance methods of this class
            public_instance_methods(false))

          methods.map!(&:to_s)

          methods.to_set
        end
      end
    end

    attr_reader :params, :notification_name

    def initialize(notification_name, **params)
      @notification_name = notification_name
      @params = params.freeze
    end

    def process_action(...)
      public_send(...)
    end

    def deliver!(notification)
      self.class.driver.call(notification.payload)
    end

    def notification(**payload)
      merge_defaults!(payload)

      raise ArgumentError, "Notification body must be present" if
        payload[:body].nil? || payload[:body].empty?

      @notification = Notification.new(payload)
    end

    private

    def merge_defaults!(payload)
      defaults =
        if self.class.defaults_generator
          instance_exec(&self.class.defaults_generator)
        else
          self.class.default_params
        end

      defaults.each do |k, v|
        payload[k] = v unless payload.key?(k)
      end
    end
  end
end
