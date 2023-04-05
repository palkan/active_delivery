# frozen_string_literal: true

require "spec_helper"

describe "ActiveJob adapter", skip: !defined?(ActiveJob) do
  before { AbstractNotifier.delivery_mode = :normal }
  after { AbstractNotifier.delivery_mode = :test }

  let(:notifier_class) do
    AbstractNotifier::TestNotifier =
      Class.new(AbstractNotifier::Base) do
        self.driver = TestDriver
        self.async_adapter = :active_job

        def tested(title, text)
          notification(
            body: "Notification #{title}: #{text}"
          )
        end
      end
  end

  after do
    AbstractNotifier.send(:remove_const, :TestNotifier) if
      AbstractNotifier.const_defined?(:TestNotifier)
  end

  describe "#enqueue" do
    specify do
      expect { notifier_class.tested("a", "b").notify_later }
        .to have_enqueued_job(AbstractNotifier::AsyncAdapters::ActiveJob::DeliveryJob)
        .with("AbstractNotifier::TestNotifier", body: "Notification a: b")
        .on_queue("notifiers")
    end

    context "when queue specified" do
      before do
        notifier_class.async_adapter = :active_job, {queue: "test"}
      end

      specify do
        expect { notifier_class.tested("a", "b").notify_later }
          .to have_enqueued_job(
            AbstractNotifier::AsyncAdapters::ActiveJob::DeliveryJob
          )
          .with("AbstractNotifier::TestNotifier", body: "Notification a: b")
          .on_queue("test")
      end
    end

    context "when custom job class specified" do
      let(:job_class) do
        AbstractNotifier::TestNotifier::Job = Class.new(ActiveJob::Base)
      end

      before do
        notifier_class.async_adapter = :active_job, {job: job_class}
      end

      specify do
        expect { notifier_class.tested("a", "b").notify_later }
          .to have_enqueued_job(job_class)
          .with("AbstractNotifier::TestNotifier", body: "Notification a: b")
          .on_queue("notifiers")
      end
    end
  end
end
