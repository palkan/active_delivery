# frozen_string_literal: true

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
  class Base
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

      def register_line(line_id, line_class, **options)
        delivery_lines[line_id] = line_class.new(id: line_id, owner: self, **options)

        instance_eval <<~CODE, __FILE__, __LINE__ + 1
          def #{line_id}(val)
            delivery_lines[:#{line_id}].handler_class = val
          end

          def #{line_id}_class
            delivery_lines[:#{line_id}].handler_class
          end
        CODE
      end
    end

    attr_reader :params

    def initialize(**params)
      @params = params
      @params.freeze
    end

    # Enqueues delivery (i.e. uses #deliver_later for mailers)
    def notify(mid, *args, sync: false)
      delivery_lines.each do |type, line|
        next if line.handler_class.nil?
        next unless line.notify?(mid)

        notify_line(type, mid, *args, params: params, sync: sync)
      end
    end

    # The same as .notify but delivers synchronously
    # (i.e. #deliver_now for mailers)
    def notify!(mid, *args, **hargs)
      notify(mid, *args, **hargs, sync: true)
    end

    private

    def notify_line(type, mid, *args)
      delivery_lines[type].notify(mid, *args)
    end

    def delivery_lines
      self.class.delivery_lines
    end
  end
end
