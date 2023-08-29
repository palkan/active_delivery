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

  it "returns NotificationDelivery object" do
    expect(notifier_class.tested("Hello", "world")).to be_a(AbstractNotifier::NotificationDelivery)
  end

  specify "#notify_later" do
    expect { notifier_class.tested("a", "b").notify_later }
      .to change { AbstractNotifier.async_adapter.jobs.size }.by(1)

    notifier, action_name, _params, args, kwargs = AbstractNotifier.async_adapter.jobs.last

    expect(notifier).to be_eql(notifier_class.name)
    expect(action_name).to eq(:tested)
    expect(args).to eq(["a", "b"])
    expect(kwargs).to be_empty
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

  describe "callbacks", skip: !defined?(ActiveSupport) do
    let(:user_class) { Struct.new(:name, :locale, :address, keyword_init: true) }

    let(:notifier_class) do
      AbstractNotifier::TestNotifier =
        Class.new(described_class) do
          class << self
            attr_reader :events
          end

          @events = []

          self.driver = TestDriver

          attr_reader :user

          before_action do
            if params
              @user = params[:user]
            end
          end

          before_action :ensure_user_has_address

          around_action(only: :tested) do |_, block|
            @user.locale = :fr
            block.call
          ensure
            @user.locale = :en
          end

          before_deliver do
            self.class.events << [notification_name, :before_deliver]
          end

          after_deliver do
            self.class.events << [notification_name, :after_deliver]
          end

          after_action do
            self.class.events << [notification_name, :after_action]
          end

          def tested(text)
            notification(
              body: "Notification for #{user.name} [#{user.locale}]: #{text}",
              to: user.address
            )
          end

          def another_event(text)
            notification(
              body: "Another event for #{user.name} [#{user.locale}]: #{text}",
              to: user.address
            )
          end

          private

          def ensure_user_has_address
            return false unless user&.address

            true
          end
        end
    end

    let(:user) { user_class.new(name: "Arthur", locale: "uk", address: "123-123") }

    specify "when callbacks pass" do
      expect { notifier_class.with(user:).tested("bonjour").notify_now }
        .to change { notifier_class.driver.deliveries.size }.by(1)

      expect(last_delivery).to eq(body: "Notification for Arthur [fr]: bonjour", to: "123-123")
    end

    specify "when a callback is not fired for the action" do
      expect { notifier_class.with(user:).another_event("hello").notify_now }
        .to change { notifier_class.driver.deliveries.size }.by(1)

      expect(last_delivery).to eq(body: "Another event for Arthur [uk]: hello", to: "123-123")
    end

    specify "when callback chain is interrupted" do
      user.address = nil
      expect { notifier_class.with(user:).tested("bonjour").notify_now }
        .not_to change { notifier_class.driver.deliveries.size }
    end

    specify "delivery callbacks" do
      notification = notifier_class.with(user:).tested("bonjour")
      expect(notifier_class.events).to be_empty

      queue = Object.new
      queue.define_singleton_method(:enqueue) do |notifier_class, action_name, params:, args:, kwargs:|
        @backlog ||= []
        @backlog << [notifier_class, action_name, params, args, kwargs]
      end

      queue.define_singleton_method(:process) do
        @backlog.each do |notifier_class, action_name, params, args, kwargs|
          AbstractNotifier::NotificationDelivery.new(notifier_class.constantize, action_name, params:, args:, kwargs:).notify_now
        end
      end

      notifier_class.async_adapter = queue

      notification.notify_later

      # Still empty: both delivery and action callbacks are called only on delivery
      expect(notifier_class.events).to be_empty

      # Trigger notification building
      notification.processed

      expect(notifier_class.events.size).to eq(1)
      expect(notifier_class.events.first).to eq([:tested, :after_action])

      notifier_class.events.clear

      queue.process

      expect(notifier_class.events.size).to eq(3)
      expect(notifier_class.events[0]).to eq([:tested, :after_action])
      expect(notifier_class.events[1]).to eq([:tested, :before_deliver])
      expect(notifier_class.events[2]).to eq([:tested, :after_deliver])
    end
  end
end
