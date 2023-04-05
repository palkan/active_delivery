# frozen_string_literal: true

module ActiveDelivery
  class Delivery # :nodoc:
    attr_reader :params, :options, :metadata, :notification, :owner

    def initialize(owner, notification:, params:, options:, metadata:)
      @owner = owner
      @notification = notification
      @params = params.freeze
      @options = options.freeze
      @metadata = metadata.freeze
    end

    def deliver_later = owner.perform_notify(self)

    def deliver_now = owner.perform_notify(self, sync: true)

    def delivery_class = owner.class
  end

  class << self
    # Whether to memoize resolved handler classes or not.
    # Set to false if you're using a code reloader (e.g., Zeitwerk).
    #
    # Defaults to true (i.e. memoization is enabled
    attr_accessor :cache_classes
    # Whether to enforce specifying available delivery actions via .delivers in the
    # delivery classes
    attr_accessor :deliver_actions_required
  end

  self.cache_classes = true
  self.deliver_actions_required = false

  # Base class for deliveries.
  #
  # Delivery object describes how to notify a user about
  # an event (e.g. via email or via push notification or both).
  #
  # Delivery class acts like a proxy in front of the different delivery channels
  # (i.e. mailers, notifiers). That means that calling a method on delivery class invokes the
  # same method on the corresponding class, e.g.:
  #
  #   EventsDelivery.one_hour_before(profile, event).deliver_later
  #   # or
  #   EventsDelivery.notify(:one_hour_before, profile, event)
  #
  #   # under the hood it calls
  #   EventsMailer.one_hour_before(profile, event).deliver_later
  #
  #   # and
  #   EventsNotifier.one_hour_before(profile, event).notify_later
  #
  # Delivery also supports _parameterized_ calling:
  #
  #   EventsDelivery.with(profile: profile).canceled(event).deliver_later
  #
  # The parameters could be accessed through `params` instance method (e.g.
  # to implement guard-like logic).
  #
  # When params are presents the parametrized mailer is used, i.e.:
  #
  #   EventsMailer.with(profile: profile).canceled(event).deliver_later
  #
  # See https://api.rubyonrails.org/classes/ActionMailer/Parameterized.html
  class Base
    class << self
      attr_accessor :abstract_class

      alias_method :with, :new

      # Enqueues delivery (i.e. uses #deliver_later for mailers)
      def notify(...)
        new.notify(...)
      end

      # The same as .notify but delivers synchronously
      # (i.e. #deliver_now for mailers)
      def notify!(mid, *args, **hargs)
        notify(mid, *args, **hargs, sync: true)
      end

      alias_method :notify_now, :notify!

      def delivery_lines
        @lines ||= if superclass.respond_to?(:delivery_lines)
          superclass.delivery_lines.each_with_object({}) do |(key, val), acc|
            acc[key] = val.dup_for(self)
          end
        else
          {}
        end
      end

      def register_line(line_id, line_class = nil, notifier: nil, **options)
        raise ArgumentError, "A line class or notifier configuration must be provided" if line_class.nil? && notifier.nil?

        # Configure Notifier
        if line_class.nil?
          line_class = ActiveDelivery::Lines::Notifier
        end

        delivery_lines[line_id] = line_class.new(id: line_id, owner: self, **options)

        instance_eval <<~CODE, __FILE__, __LINE__ + 1
          def #{line_id}(val)
            delivery_lines[:#{line_id}].handler_class_name = val
          end

          def #{line_id}_class
            delivery_lines[:#{line_id}].handler_class
          end
        CODE
      end

      def unregister_line(line_id)
        removed_line = delivery_lines.delete(line_id)

        return if removed_line.nil?

        singleton_class.undef_method line_id
        singleton_class.undef_method "#{line_id}_class"
      end

      def abstract_class? = abstract_class == true

      # Specify explicitly which actions are supported by the delivery.
      def delivers(*actions)
        actions.each do |mid|
          class_eval <<~CODE, __FILE__, __LINE__ + 1
            def self.#{mid}(...)
              new.#{mid}(...)
            end

            def #{mid}(*args, **kwargs)
              delivery(
                notification: :#{mid},
                params: args,
                options: kwargs
              )
            end
          CODE
        end
      end

      def respond_to_missing?(mid, include_private = false)
        unless ActiveDelivery.deliver_actions_required
          return true if delivery_lines.any? { |_, line| line.notify?(mid) }
        end

        super
      end

      def method_missing(mid, *args, **kwargs)
        return super unless respond_to_missing?(mid)

        # Lazily define a class method to avoid lookups
        delivers(mid)

        public_send(mid, *args, **kwargs)
      end
    end

    self.abstract_class = true

    attr_reader :params, :notification_name

    def initialize(**params)
      @params = params
      @params.freeze
    end

    # Enqueues delivery (i.e. uses #deliver_later for mailers)
    def notify(mid, *args, **kwargs)
      perform_notify(
        delivery(notification: mid, params: args, options: kwargs)
      )
    end

    # The same as .notify but delivers synchronously
    # (i.e. #deliver_now for mailers)
    def notify!(mid, *args, **kwargs)
      perform_notify(
        delivery(notification: mid, params: args, options: kwargs),
        sync: true
      )
    end

    alias_method :notify_now, :notify!

    def respond_to_missing?(mid, include_private = false)
      unless ActiveDelivery.deliver_actions_required
        return true if delivery_lines.any? { |_, line| line.notify?(mid) }
      end

      super
    end

    def method_missing(mid, *args, **kwargs)
      return super unless respond_to_missing?(mid)

      # Lazily define a method to avoid future lookups
      self.class.class_eval <<~CODE, __FILE__, __LINE__ + 1
        def #{mid}(*args, **kwargs)
          delivery(
            notification: :#{mid},
            params: args,
            options: kwargs
          )
        end
      CODE

      public_send(mid, *args, **kwargs)
    end

    protected

    def perform_notify(delivery, sync: false)
      delivery_lines.each do |type, line|
        next unless line.notify?(delivery.notification)

        notify_line(type, line, delivery, sync:)
      end
    end

    private

    def notify_line(type, line, delivery, sync:)
      line.notify(
        delivery.notification,
        *delivery.params,
        params:,
        sync:,
        **delivery.options
      )
      true
    end

    def delivery(notification:, params: nil, options: nil, metadata: nil)
      Delivery.new(self, notification:, params:, options:, metadata:)
    end

    def delivery_lines
      self.class.delivery_lines
    end
  end
end
