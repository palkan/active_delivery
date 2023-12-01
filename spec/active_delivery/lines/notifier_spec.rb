# frozen_string_literal: true

require "spec_helper"

describe ActiveDelivery::Lines::Notifier do
  before do
    module ::DeliveryTesting # rubocop:disable Lint/ConstantDefinitionInBlock
      class TestNotifier < AbstractNotifier::Base
        def do_something(msg)
          notification(
            body: msg,
            to: params[:user]
          )
        end

        private

        def do_nothing
        end
      end

      class TestReverseNotifier < AbstractNotifier::Base
        def do_something(msg)
          notification(
            body: msg.reverse,
            to: params[:user]
          )
        end
      end

      class CustomNotifier < AbstractNotifier::Base
        def do_something(msg)
          notification(
            body: "[CUSTOM] #{msg}",
            to: params[:user]
          )
        end
      end

      class TestDelivery < ActiveDelivery::Base
        register_line :notifier, notifier: true
        register_line :reverse_notifier, notifier: true, suffix: "ReverseNotifier"
        register_line :pattern_notifier, notifier: true, resolver_pattern: "%{delivery_class}::%{delivery_name}Notifier"
        register_line :custom_notifier, notifier: true,
          resolver: proc { CustomNotifier }

        class TestNotifier < AbstractNotifier::Base
          def do_something(msg)
            notification(
              body: "[NESTED] #{msg}",
              to: params[:user]
            )
          end
        end
      end
    end
  end

  after do
    Object.send(:remove_const, :DeliveryTesting)
  end

  let(:delivery_class) { ::DeliveryTesting::TestDelivery }
  let(:notifier_class) { ::DeliveryTesting::TestNotifier }
  let(:reverse_notifier_class) { ::DeliveryTesting::TestReverseNotifier }
  let(:pattern_notifier_class) { ::DeliveryTesting::TestDelivery::TestNotifier }
  let(:custom_notifier_class) { ::DeliveryTesting::CustomNotifier }

  describe ".notifier_class" do
    it "infers notifier from delivery name" do
      expect(delivery_class.notifier_class).to be_eql(notifier_class)
      expect(delivery_class.reverse_notifier_class).to be_eql(reverse_notifier_class)
      expect(delivery_class.pattern_notifier_class).to be_eql(pattern_notifier_class)
      expect(delivery_class.custom_notifier_class).to be_eql(custom_notifier_class)
    end
  end

  describe "#delivery_later" do
    it "enqueues notification" do
      expect { delivery_class.with(user: "Bart").do_something("Magic people voodoo people!").deliver_later }
        .to have_enqueued_notification(via: notifier_class, body: "Magic people voodoo people!", to: "Bart")
        .and have_enqueued_notification(via: reverse_notifier_class, body: "!elpoep oodoov elpoep cigaM", to: "Bart")
        .and have_enqueued_notification(via: pattern_notifier_class, body: "[NESTED] Magic people voodoo people!", to: "Bart")
        .and have_enqueued_notification(via: custom_notifier_class, body: "[CUSTOM] Magic people voodoo people!", to: "Bart")
    end

    context "with delivery options" do
      it "enqueues notification with options" do
        expect { delivery_class.with(user: "Bart").do_something("Magic people voodoo people!").deliver_later(queue: "test") }
          .to have_enqueued_notification(via: notifier_class, body: "Magic people voodoo people!", to: "Bart", queue: "test")
          .and have_enqueued_notification(via: reverse_notifier_class, body: "!elpoep oodoov elpoep cigaM", to: "Bart", queue: "test")
          .and have_enqueued_notification(via: pattern_notifier_class, body: "[NESTED] Magic people voodoo people!", to: "Bart", queue: "test")
          .and have_enqueued_notification(via: custom_notifier_class, body: "[CUSTOM] Magic people voodoo people!", to: "Bart", queue: "test")
      end
    end
  end

  describe "#notify" do
    it "do nothing when notifier doesn't have provided public method" do
      expect { delivery_class.notify(:do_nothing) }
        .not_to have_enqueued_notification
    end
  end

  describe ".notify!" do
    it "sends notification" do
      expect { delivery_class.with(user: "Bart").notify!(:do_something, "Voyage-voyage!") }
        .to have_sent_notification(via: notifier_class, body: "Voyage-voyage!", to: "Bart")
        .and have_sent_notification(via: reverse_notifier_class, body: "!egayov-egayoV", to: "Bart")
        .and have_sent_notification(via: pattern_notifier_class, body: "[NESTED] Voyage-voyage!", to: "Bart")
        .and have_sent_notification(via: custom_notifier_class, body: "[CUSTOM] Voyage-voyage!", to: "Bart")
    end
  end
end
