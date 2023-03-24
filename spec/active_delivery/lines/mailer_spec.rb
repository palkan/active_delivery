# frozen_string_literal: true

return unless defined?(ActionMailer)

# rubocop:disable Lint/ConstantDefinitionInBlock
describe "ActionMailer line" do
  before do
    module ::DeliveryTesting
      class TestMailer < ActionMailer::Base
        def do_something
        end

        def do_another_thing(key:)
        end

        private

        def do_nothing
        end
      end

      class CustomMailer < ActionMailer::Base
      end

      class TestDelivery < ActiveDelivery::Base
        register_line :custom_mailer, ActiveDelivery::Lines::Mailer, resolver: ->(name) { CustomMailer }
      end
    end
  end

  after do
    Object.send(:remove_const, :DeliveryTesting)
  end

  let(:delivery_class) { ::DeliveryTesting::TestDelivery }
  let(:mailer_class) { ::DeliveryTesting::TestMailer }
  let(:custom_mailer_class) { ::DeliveryTesting::CustomMailer }

  describe ".mailer_class" do
    it "infers mailer from delivery name" do
      expect(delivery_class.mailer_class).to be_eql(mailer_class)
    end
  end

  describe ".custom_mailer_class" do
    it "infers mailer from resolver" do
      expect(delivery_class.custom_mailer_class).to be_eql(custom_mailer_class)
    end
  end

  describe ".with" do
    it "doesn't raises error" do
      expect { delivery_class.with(test_param: true).notify(:do_something) }.not_to raise_error
    end

    it "sets params" do
      expect(delivery_class.with(test_param: true).params).to eq(test_param: true)
    end
  end

  describe ".notify" do
    let(:mailer_instance) { double("mailer") }

    before { allow(mailer_class).to receive(:do_something).and_return(mailer_instance) }

    describe ".notify" do
      it "calls deliver_later on mailer instance" do
        expect(mailer_instance).to receive(:deliver_later)

        delivery_class.notify(:do_something)
      end

      it "do nothing when mailer doesn't have provided public method", skip: (ActionMailer::VERSION::MAJOR < 6) do
        delivery_class.notify(:do_another_thing, key: :test)
      end

      it "supports kwargs" do
        expect(mailer_instance).to receive(:deliver_later)

        delivery_class.notify(:do_something)
      end
    end

    describe ".notify!" do
      it "calls deliver_now on mailer instance" do
        expect(mailer_instance).to receive(:deliver_now)

        delivery_class.notify!(:do_something)
      end
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
