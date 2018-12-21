# frozen_string_literal: true

module ActiveDelivery
  module Lines
    class Mailer < Base
      alias mailer_class handler_class

      def resolve_class(name)
        name.gsub(/Delivery$/, "Mailer").safe_constantize
      end

      def notify?(method_name)
        mailer_class.action_methods.include?(method_name.to_s)
      end

      def notify_now(mailer, mid, *args)
        mailer.public_send(mid, *args).deliver_now
      end

      def notify_later(mailer, mid, *args)
        mailer.public_send(mid, *args).deliver_later
      end
    end

    ActiveDelivery::Base.register_line :mailer, Mailer
  end
end
