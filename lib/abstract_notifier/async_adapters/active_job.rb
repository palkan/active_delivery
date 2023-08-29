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

      attr_reader :job

      def initialize(queue: DEFAULT_QUEUE, job: DeliveryJob)
        @job = job.set(queue: queue)
      end

      def enqueue(...)
        job.perform_later(...)
      end
    end
  end
end

AbstractNotifier.async_adapter ||= :active_job
