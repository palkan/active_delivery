# frozen_string_literal: true

if ActionMailer::VERSION::MAJOR < 5
  require "active_delivery/action_mailer/parameterized"
end

module ActiveDelivery
  module Lines
    class Mailer < Base
      alias mailer_class handler_class

      DEFAULT_RESOLVER = ->(name) { name.gsub(/Delivery$/, "Mailer").safe_constantize }

      def notify?(method_name)
        mailer_class.action_methods.include?(method_name.to_s)
      end

      def notify_now(mailer, mid, *args, **kwargs)
        if kwargs.empty?
          mailer.public_send(mid, *args).deliver_now
        else
          mailer.public_send(mid, *args, **kwargs).deliver_now
        end
      end

      def notify_later(mailer, mid, *args, **kwargs)
        if kwargs.empty?
          mailer.public_send(mid, *args).deliver_later
        else
          mailer.public_send(mid, *args, **kwargs).deliver_later
        end
      end
    end

    ActiveDelivery::Base.register_line :mailer, Mailer, resolver: Mailer::DEFAULT_RESOLVER
  end
end
