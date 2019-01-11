# frozen_string_literal: true

require "active_support/version"
require "active_support/callbacks"
require "active_support/concern"

module ActiveDelivery
  # Add callbacks support to Active Delivery (requires ActiveSupport::Callbacks)
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
  module Callbacks
    extend ActiveSupport::Concern

    include ActiveSupport::Callbacks

    CALLBACK_TERMINATOR = if ::ActiveSupport::VERSION::MAJOR >= 5
      ->(_target, result) { result.call == false }
    else
      ->(_target, result) { result == false }
    end

    included do
      # Define "global" callbacks
      define_line_callbacks :notify

      prepend InstanceExt
      singleton_class.prepend SingltonExt
    end

    module InstanceExt
      def do_notify(*)
        run_callbacks(:notify) { super }
      end

      def notify_line(type, *)
        run_callbacks(type) { super }
      end
    end

    module SingltonExt
      def register_line(line_id, *args)
        super
        define_line_callbacks line_id
      end
    end

    class_methods do
      def define_line_callbacks(name)
        define_callbacks name,
                         terminator: CALLBACK_TERMINATOR,
                         skip_after_callbacks_if_terminated: true
      end

      def before_notify(method_or_block = nil, on: :notify)
        method_or_block ||= Proc.new
        set_callback on, :before, method_or_block
      end

      def after_notify(method_or_block = nil, on: :notify)
        method_or_block ||= Proc.new
        set_callback on, :after, method_or_block
      end

      def around_notify(method_or_block = nil, on: :notify)
        method_or_block ||= Proc.new
        set_callback on, :around, method_or_block
      end
    end
  end
end

ActiveDelivery::Base.include ActiveDelivery::Callbacks
