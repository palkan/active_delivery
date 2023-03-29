# frozen_string_literal: true

require "active_support/version"
require "active_support/callbacks"
require "active_support/concern"

module ActiveDelivery
  # Add callbacks support to Active Delivery (requires ActiveSupport::Callbacks)
  #
  #   # Run method before delivering notification
  #   # NOTE: when `false` is returned the execution is halted
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

    CALLBACK_TERMINATOR = ->(_target, result) { result.call == false }

    included do
      # Define "global" callbacks
      define_line_callbacks :notify

      prepend InstanceExt
      singleton_class.prepend SingltonExt
    end

    module InstanceExt
      def perform_notify(delivery, ...)
        # We need to store the notification name to be able to use it in callbacks if/unless
        @notification_name = delivery.notification
        run_callbacks(:notify) { super(delivery, ...) }
      end

      def notify_line(kind, ...)
        run_callbacks(kind) { super(kind, ...) }
      end
    end

    module SingltonExt
      def register_line(line_id, ...)
        super
        define_line_callbacks line_id
      end
    end

    class_methods do
      def _normalize_callback_options(options)
        _normalize_callback_option(options, :only, :if)
        _normalize_callback_option(options, :except, :unless)
      end

      def _normalize_callback_option(options, from, to)
        if (from = options[from])
          from_set = Array(from).map(&:to_s).to_set
          from = proc { |c| from_set.include? c.notification_name.to_s }
          options[to] = Array(options[to]).unshift(from)
        end
      end

      def define_line_callbacks(name)
        define_callbacks name,
          terminator: CALLBACK_TERMINATOR,
          skip_after_callbacks_if_terminated: true
      end

      %i[before after around].each do |kind|
        define_method "#{kind}_notify" do |*names, on: :notify, **options, &block|
          _normalize_callback_options(options)

          names.each do |name|
            set_callback on, kind, name, options
          end

          set_callback on, kind, block, options if block
        end

        define_method "skip_#{kind}_notify" do |*names, on: :notify, **options|
          _normalize_callback_options(options)

          names.each do |name|
            skip_callback(on, kind, name, options)
          end
        end
      end
    end
  end
end

ActiveDelivery::Base.include ActiveDelivery::Callbacks
