# frozen_string_literal: true

require "active_support/callbacks"

module ActiveDelivery
  # Base class for deliveries.
  #
  # Delivery object describes how to notify a user about
  # an event (e.g. via email or via push notification or both).
  #
  # Delivery class acts like a proxy in front of the different delivery channels
  # (i.e. mailers, notifiers). That means that calling a method on delivery class invokes the
  # same method on the corresponding class, e.g.:
  #
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
  #   EventsDelivery.with(profile: profile).notify(:canceled, event)
  #
  # The parameters could be accessed through `params` instance method (e.g.
  # to implement guard-like logic).
  #
  # When params are presents the parametrized mailer is used, i.e.:
  #
  #   EventsMailer.with(profile: profile).canceled(event)
  #
  # See https://api.rubyonrails.org/classes/ActionMailer/Parameterized.html
  #
  # Callbacks support:
  #
  #   # Run method before delivering notification
  #   # NOTE: when `false` is returned the executation is halted
  #   before_notify :do_something
  #
  #   # You can specify a notification method (to run callback only for that method)
  #   before_notify :do_mail_something, on: :mail
  #
  #   # or for push notifications
  #   before_notify :do_mail_something, on: :push
  #
  #   # after_ and around_ callbacks are also supported
  #   after_notify :cleanup
  #
  #   around_notify :set_context
  #
  class Base
    include ActiveSupport::Callbacks

    class << self
      alias with new

      # Enqueues delivery (i.e. uses #deliver_later for mailers)
      def notify(*args)
        new.notify(*args)
      end

      # The same as .notify but delivers synchronously
      # (i.e. #deliver_now for mailers)
      def notify!(mid, *args, **hargs)
        notify(mid, *args, **hargs, sync: true)
      end

      def delivery_lines
        @lines ||= begin
          if superclass.respond_to?(:delivery_lines)
            superclass.delivery_lines.each_with_object({}) do |(key, val), acc|
              acc[key] = val.dup_for(self)
            end
          else
            {}
          end
        end
      end

      def register_line(line_id, line_class)
        delivery_lines[line_id] = line_class.new(line_id, self)

        instance_eval <<~CODE, __FILE__, __LINE__ + 1
          def #{line_id}(val)
            delivery_lines[:#{line_id}].handler_class = val
          end

          def #{line_id}_class
            delivery_lines[:#{line_id}].handler_class
          end
        CODE

        define_callbacks line_id,
                         terminator: ->(_target, result_lambda) { result_lambda.call == false },
                         skip_after_callbacks_if_terminated: true
      end

      def before_notify(method_name, on: :notify)
        set_callback on, :before, method_name
      end

      def after_notify(method_name, on: :notify)
        set_callback on, :after, method_name
      end

      def around_notify(method_name, on: :notify)
        set_callback on, :around, method_name
      end
    end

    define_callbacks :notify,
                     terminator: ->(_target, result_lambda) { result_lambda.call == false },
                     skip_after_callbacks_if_terminated: true

    attr_reader :params

    def initialize(**params)
      @params = params
      @params.freeze
    end

    # Enqueues delivery (i.e. uses #deliver_later for mailers)
    def notify(mid, *args, sync: false)
      run_callbacks(:notify) do
        delivery_lines.each do |type, line|
          next if line.handler_class.nil?
          next unless line.notify?(mid)

          run_callbacks(type) do
            line.notify(mid, *args, params: params, sync: sync)
          end
        end
      end
    end

    # The same as .notify but delivers synchronously
    # (i.e. #deliver_now for mailers)
    def notify!(mid, *args, **hargs)
      notify(mid, *args, **hargs, sync: true)
    end

    private

    def delivery_lines
      self.class.delivery_lines
    end
  end
end
