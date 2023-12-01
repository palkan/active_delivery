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

    module NotificationDelivery
      def notify_now
        return super unless AbstractNotifier.test?

        payload = notification.payload

        Driver.send_notification payload.merge(via: notifier.class)
      end

      def notify_later(**opts)
        return super unless AbstractNotifier.test?

        payload = notification.payload

        Driver.enqueue_notification payload.merge(via: notifier.class, **opts)
      end
    end
  end
end

AbstractNotifier::NotificationDelivery.prepend AbstractNotifier::Testing::NotificationDelivery

require "abstract_notifier/testing/rspec" if defined?(RSpec::Core)
require "abstract_notifier/testing/minitest" if defined?(Minitest::Assertions)
