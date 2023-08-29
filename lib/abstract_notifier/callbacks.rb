# frozen_string_literal: true

require "active_support/version"
require "active_support/callbacks"
require "active_support/concern"

module AbstractNotifier
  # Add callbacks support to Abstract Notifier (requires ActiveSupport::Callbacks)
  #
  #   # Run method before seding notification
  #   # NOTE: when `false` is returned the execution is halted
  #   before_action :do_something
  #
  #   # after_ and around_ callbacks are also supported
  #   after_action :cleanup
  #
  #   around_action :set_context
  #
  #   # Deliver callbacks are also available
  #   before_deliver :do_something
  #
  #   # after_ and around_ callbacks are also supported
  #   after_deliver :cleanup
  #
  #   around_deliver :set_context
  module Callbacks
    extend ActiveSupport::Concern

    include ActiveSupport::Callbacks

    CALLBACK_TERMINATOR = ->(_target, result) { result.call == false }

    included do
      define_callbacks :action,
        terminator: CALLBACK_TERMINATOR,
        skip_after_callbacks_if_terminated: true

      define_callbacks :deliver,
        terminator: CALLBACK_TERMINATOR,
        skip_after_callbacks_if_terminated: true

      prepend InstanceExt
    end

    module InstanceExt
      def process_action(...)
        run_callbacks(:action) { super(...) }
      end

      def deliver!(...)
        run_callbacks(:deliver) { super(...) }
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

      %i[before after around].each do |kind|
        %i[action deliver].each do |event|
          define_method "#{kind}_#{event}" do |*names, on: event, **options, &block|
            _normalize_callback_options(options)

            names.each do |name|
              set_callback on, kind, name, options
            end

            set_callback on, kind, block, options if block
          end

          define_method "skip_#{kind}_#{event}" do |*names, on: event, **options|
            _normalize_callback_options(options)

            names.each do |name|
              skip_callback(on, kind, name, options)
            end
          end
        end
      end
    end
  end
end

AbstractNotifier::Base.include AbstractNotifier::Callbacks
