# frozen_string_literal: true

module AbstractNotifier
  module Testing
    module Driver
      class << self
        def deliveries
          Thread.current[:notifier_deliveries] ||= []
        end

        def enqueued_deliveries
          Thread.current[:notifier_enqueued_deliveries] ||= []
        end

        def clear
          deliveries.clear
          enqueued_deliveries.clear
        end

        def send_notification(data)
          deliveries << data
        end

        def enqueue_notification(data)
          enqueued_deliveries << data
        end
      end
    end

    module Notification
      def notify_now
        return super unless AbstractNotifier.test?

        Driver.send_notification payload.merge(via: owner)
      end

      def notify_later
        return super unless AbstractNotifier.test?

        Driver.enqueue_notification payload.merge(via: owner)
      end
    end
  end
end

AbstractNotifier::Notification.prepend AbstractNotifier::Testing::Notification

require "abstract_notifier/testing/rspec" if defined?(RSpec::Core)
require "abstract_notifier/testing/minitest" if defined?(Minitest::Assertions)
