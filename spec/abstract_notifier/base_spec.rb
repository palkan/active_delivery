# frozen_string_literal: true

require "spec_helper"

describe AbstractNotifier::Base do
  before { AbstractNotifier.delivery_mode = :normal }
  after { AbstractNotifier.delivery_mode = :test }

  let(:notifier_class) do
    AbstractNotifier::TestNotifier =
      Class.new(described_class) do
        self.driver = TestDriver

        def tested(title, text)
          notification(
            body: "Notification #{title}: #{text}"
          )
        end
      end
  end

  let(:last_delivery) { notifier_class.driver.deliveries.last }

  after do
    AbstractNotifier.send(:remove_const, :TestNotifier) if
      AbstractNotifier.const_defined?(:TestNotifier)
  end

  it "returns Notification object" do
    expect(notifier_class.tested("Hello", "world")).to be_a(AbstractNotifier::Notification)
  end

  specify "#notify_later" do
    expect { notifier_class.tested("a", "b").notify_later }
      .to change { AbstractNotifier.async_adapter.jobs.size }.by(1)

    notifier, payload = AbstractNotifier.async_adapter.jobs.last

    expect(notifier).to be_eql(notifier_class)
    expect(payload).to eq(body: "Notification a: b")
  end

  specify "#notify_now" do
    expect { notifier_class.tested("a", "b").notify_now }
      .to change { notifier_class.driver.deliveries.size }.by(1)
    expect(last_delivery).to eq(body: "Notification a: b")
  end

  describe ".with" do
    let(:notifier_class) do
      AbstractNotifier::TestNotifier =
        Class.new(described_class) do
          self.driver = TestDriver

          def tested
            notification(**params)
          end
        end
    end

    it "sets params" do
      expect { notifier_class.with(body: "how are you?", to: "123-123").tested.notify_now }
        .to change { notifier_class.driver.deliveries.size }.by(1)

      expect(last_delivery).to eq(body: "how are you?", to: "123-123")
    end
  end

  describe ".default" do
    context "static defaults" do
      let(:notifier_class) do
        AbstractNotifier::TestNotifier =
          Class.new(described_class) do
            self.driver = TestDriver

            default action: "TESTO"

            def tested(options = {})
              notification(**options)
            end
          end
      end

      it "adds defaults to notification if missing" do
        expect { notifier_class.tested(body: "how are you?", to: "123-123").notify_now }
          .to change { notifier_class.driver.deliveries.size }.by(1)

        expect(last_delivery).to eq(body: "how are you?", to: "123-123", action: "TESTO")
      end

      it "doesn't overwrite if key is provided" do
        expect { notifier_class.tested(body: "how are you?", to: "123-123", action: "OTHER").notify_now }
          .to change { notifier_class.driver.deliveries.size }.by(1)

        expect(last_delivery).to eq(body: "how are you?", to: "123-123", action: "OTHER")
      end
    end

    context "dynamic defaults as method_name" do
      let(:notifier_class) do
        AbstractNotifier::TestNotifier =
          Class.new(described_class) do
            self.driver = TestDriver

            default :set_defaults

            def tested(options = {})
              notification(**options)
            end

            private

            def set_defaults
              {
                action: notification_name.to_s.upcase
              }
            end
          end
      end

      it "adds defaults to notification if missing" do
        expect { notifier_class.tested(body: "how are you?", to: "123-123").notify_now }
          .to change { notifier_class.driver.deliveries.size }.by(1)

        expect(last_delivery).to eq(body: "how are you?", to: "123-123", action: "TESTED")
      end

      it "doesn't overwrite if key is provided" do
        expect { notifier_class.tested(body: "how are you?", to: "123-123", action: "OTHER").notify_now }
          .to change { notifier_class.driver.deliveries.size }.by(1)

        expect(last_delivery).to eq(body: "how are you?", to: "123-123", action: "OTHER")
      end
    end

    context "dynamic defaults as block" do
      let(:notifier_class) do
        AbstractNotifier::TestNotifier =
          Class.new(described_class) do
            self.driver = TestDriver

            default do
              {
                action: notification_name.to_s.upcase
              }
            end

            def tested(options = {})
              notification(**options)
            end
          end
      end

      it "adds defaults to notification if missing" do
        expect { notifier_class.tested(body: "how are you?", to: "123-123").notify_now }
          .to change { notifier_class.driver.deliveries.size }.by(1)

        expect(last_delivery).to eq(body: "how are you?", to: "123-123", action: "TESTED")
      end

      it "doesn't overwrite if key is provided" do
        expect { notifier_class.tested(body: "how are you?", to: "123-123", action: "OTHER").notify_now }
          .to change { notifier_class.driver.deliveries.size }.by(1)

        expect(last_delivery).to eq(body: "how are you?", to: "123-123", action: "OTHER")
      end
    end
  end

  describe ".driver=" do
    let(:notifier_class) do
      AbstractNotifier::TestNotifier =
        Class.new(described_class) do
          self.driver = TestDriver

          def tested(text)
            notification(
              body: "Notification: #{text}",
              **params
            )
          end
        end
    end

    let(:fake_driver) { double("driver") }

    around do |ex|
      old_driver = notifier_class.driver
      notifier_class.driver = fake_driver
      ex.run
      notifier_class.driver = old_driver
    end

    specify do
      allow(fake_driver).to receive(:call)
      notifier_class.with(identity: "qwerty123", tag: "all").tested("fake!").notify_now
      expect(fake_driver).to have_received(
        :call
      ).with(body: "Notification: fake!", identity: "qwerty123", tag: "all")
    end
  end
end
