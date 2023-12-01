# frozen_string_literal: true

require "spec_helper"

describe "ActiveJob adapter", skip: !defined?(ActiveJob) do
  if defined?(ActiveJob::TestHelper)
    include ActiveJob::TestHelper
  end

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

        def params_tested(a, b, locale: :en)
          notification(
            body: "Notification for #{params[:user]} [#{locale}]: #{a}=#{b}"
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
        .with("AbstractNotifier::TestNotifier", :tested, params: {}, args: ["a", "b"], kwargs: {})
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
          .with("AbstractNotifier::TestNotifier", :tested, params: {}, args: ["a", "b"], kwargs: {})
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
          .with("AbstractNotifier::TestNotifier", :tested, params: {}, args: ["a", "b"], kwargs: {})
          .on_queue("notifiers")
      end
    end

    context "when params specified and method accepts kwargs" do
      specify do
        expect { notifier_class.with(foo: "bar").tested("a", "b", mode: :test).notify_later }
          .to have_enqueued_job(AbstractNotifier::AsyncAdapters::ActiveJob::DeliveryJob)
          .with("AbstractNotifier::TestNotifier", :tested, params: {foo: "bar"}, args: ["a", "b"], kwargs: {mode: :test})
          .on_queue("notifiers")
      end
    end

    context "with wait_until specified" do
      specify do
        deadline = 1.hour.from_now
        expect { notifier_class.tested("a", "b").notify_later(wait_until: deadline) }
          .to have_enqueued_job(AbstractNotifier::AsyncAdapters::ActiveJob::DeliveryJob)
          .with("AbstractNotifier::TestNotifier", :tested, params: {}, args: ["a", "b"], kwargs: {})
          .on_queue("notifiers")
          .at(deadline)
      end
    end
  end

  describe "#perform" do
    let(:last_delivery) { notifier_class.driver.deliveries.last }

    specify do
      perform_enqueued_jobs do
        expect { notifier_class.with(user: "Alice").params_tested("a", "b", locale: :fr).notify_later }
          .to change { notifier_class.driver.deliveries.size }.by(1)
      end

      expect(last_delivery).to eq(body: "Notification for Alice [fr]: a=b")
    end
  end
end
