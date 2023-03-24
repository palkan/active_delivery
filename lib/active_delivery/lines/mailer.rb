# frozen_string_literal: true

module ActiveDelivery
  module Lines
    class Mailer < Base
      alias_method :mailer_class, :handler_class

      DEFAULT_RESOLVER = ->(name) { name&.gsub(/Delivery$/, "Mailer")&.safe_constantize }

      def notify?(method_name)
        mailer_class.action_methods.include?(method_name.to_s)
      end

      def notify_now(mailer, mid, ...)
        mailer.public_send(mid, ...).deliver_now
      end

      def notify_later(mailer, mid, ...)
        mailer.public_send(mid, ...).deliver_later
      end
    end

    ActiveDelivery::Base.register_line :mailer, Mailer, resolver: Mailer::DEFAULT_RESOLVER
  end
end
