# frozen_string_literal: true

module AbstractNotifier
  module AsyncAdapters
    class ActiveJob
      class DeliveryJob < ::ActiveJob::Base
        def perform(notifier_class, ...)
          AbstractNotifier::NotificationDelivery.new(notifier_class.constantize, ...).notify_now
        end
      end

      DEFAULT_QUEUE = "notifiers"

      attr_reader :job, :queue

      def initialize(queue: DEFAULT_QUEUE, job: DeliveryJob)
        @job = job
        @queue = queue
      end

      def enqueue(...)
        job.set(queue:).perform_later(...)
      end

      def enqueue_delivery(delivery, **opts)
        job.set(queue:, **opts).perform_later(
          delivery.notifier_class.name,
          delivery.action_name,
          **delivery.delivery_params
        )
      end
    end
  end
end

AbstractNotifier.async_adapter ||= :active_job
