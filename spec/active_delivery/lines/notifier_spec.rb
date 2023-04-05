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
        register_line :custom_notifier, notifier: true,
          resolver: proc { CustomNotifier }
      end
    end
  end

  after do
    Object.send(:remove_const, :DeliveryTesting)
  end

  let(:delivery_class) { ::DeliveryTesting::TestDelivery }
  let(:notifier_class) { ::DeliveryTesting::TestNotifier }
  let(:reverse_notifier_class) { ::DeliveryTesting::TestReverseNotifier }
  let(:custom_notifier_class) { ::DeliveryTesting::CustomNotifier }

  describe ".notifier_class" do
    it "infers notifier from delivery name" do
      expect(delivery_class.notifier_class).to be_eql(notifier_class)
      expect(delivery_class.reverse_notifier_class).to be_eql(reverse_notifier_class)
      expect(delivery_class.custom_notifier_class).to be_eql(custom_notifier_class)
    end
  end

  describe ".notify" do
    describe ".notify" do
      it "enqueues notification" do
        expect { delivery_class.with(user: "Shnur").do_something("Magic people voodoo people!").deliver_later }
          .to have_enqueued_notification(via: notifier_class, body: "Magic people voodoo people!", to: "Shnur")
          .and have_enqueued_notification(via: reverse_notifier_class, body: "!elpoep oodoov elpoep cigaM", to: "Shnur")
          .and have_enqueued_notification(via: custom_notifier_class, body: "[CUSTOM] Magic people voodoo people!", to: "Shnur")
      end

      it "do nothing when notifier doesn't have provided public method" do
        expect { delivery_class.notify(:do_nothing) }
          .not_to have_enqueued_notification
      end
    end

    describe ".notify!" do
      it "sends notification" do
        expect { delivery_class.with(user: "Shnur").notify!(:do_something, "Voyage-voyage!") }
          .to have_sent_notification(via: notifier_class, body: "Voyage-voyage!", to: "Shnur")
          .and have_sent_notification(via: reverse_notifier_class, body: "!egayov-egayoV", to: "Shnur")
          .and have_sent_notification(via: custom_notifier_class, body: "[CUSTOM] Voyage-voyage!", to: "Shnur")
      end
    end
  end
end
