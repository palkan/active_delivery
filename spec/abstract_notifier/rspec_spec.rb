# frozen_string_literal: true

require "spec_helper"

describe "RSpec matcher" do
  let(:notifier_class) do
    AbstractNotifier::TestNotifier =
      Class.new(AbstractNotifier::Base) do
        self.driver = TestDriver

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

  describe "#have_sent_notification" do
    specify "success" do
      expect { notifier_class.tested("a", "b").notify_now }
        .to have_sent_notification(body: "Notification a: b")
    end

    specify "failure" do
      expect do
        expect { notifier_class.tested("a", "b").notify_now }
          .to have_sent_notification(body: "Notification a: x")
      end.to raise_error(/to send notification.+exactly once, but/)
    end

    specify "composed matchers" do
      expect { notifier_class.tested("a", "b").notify_now }
        .to have_sent_notification(a_hash_including(body: /notification/i))
    end

    context "when delivery_mode is not test" do
      around do |ex|
        old_mode = AbstractNotifier.delivery_mode
        AbstractNotifier.delivery_mode = :noop
        ex.run
        AbstractNotifier.delivery_mode = old_mode
      end

      specify "it raises argument error" do
        expect do
          expect { notifier_class.tested("a", "b").notify_now }
            .to have_sent_notification(body: "Notification a: b")
        end.to raise_error(/you can only use have_sent_notification matcher in :test delivery mode/i)
      end
    end
  end

  describe "#have_enqueued_notification" do
    specify "success" do
      expect { notifier_class.tested("a", "b").notify_later }
        .to have_enqueued_notification(body: "Notification a: b")
    end

    specify "failure" do
      expect do
        expect { notifier_class.tested("a", "b").notify_now }
          .to have_enqueued_notification(body: "Notification a: x")
      end.to raise_error(/to enqueue notification.+exactly once, but/)
    end
  end
end
