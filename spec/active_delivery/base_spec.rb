# frozen_string_literal: true

require "spec_helper"

# rubocop:disable Lint/DuplicateMethods, Lint/MissingCopEnableDirective
describe ActiveDelivery::Base do
  before(:all) do
    class ::QuackLine < ActiveDelivery::Lines::Base
      def resolve_class(name)
        name.gsub(/Delivery$/, "Quack").safe_constantize
      end

      def notify_now(handler, mid, *args)
        handler.public_send(mid, *args).quack_quack
      end

      def notify_later(handler, mid, *args)
        handler.public_send(mid, *args).quack_later
      end
    end

    class ::QuackkkLine < QuackLine
      def resolve_class(name)
        name.gsub(/Delivery$/, "Quackkk").safe_constantize
      end
    end

    ActiveDelivery::Base.register_line :quack, QuackLine
    ActiveDelivery::Base.register_line :quack_quack, QuackkkLine
  end

  before do
    module ::DeliveryTesting; end
  end

  after do
    Object.send(:remove_const, :DeliveryTesting)
  end

  let(:delivery_class) do
    DeliveryTesting.const_set("MyDelivery", Class.new(described_class))
  end

  describe ".<line>_class" do
    it "infers class from delivery name" do
      delivery = DeliveryTesting.const_set("MyDelivery", Class.new(described_class))

      quack_class = DeliveryTesting.const_set("MyQuack", Class.new)

      expect(delivery.quack_class).to be_eql(quack_class)
    end

    it "infers quack from superclass" do
      delivery = DeliveryTesting.const_set("MyDelivery", Class.new(described_class))
      quack_class = DeliveryTesting.const_set("ParentQuack", Class.new)

      expect(delivery.quack_class).to be_nil

      parent_delivery = DeliveryTesting.const_set("ParentDelivery", Class.new(described_class))
      sub_delivery = DeliveryTesting.const_set("SubDelivery", Class.new(parent_delivery))

      expect(sub_delivery.quack_class).to be_eql(quack_class)
    end

    it "uses explicit quack" do
      quack_class = DeliveryTesting.const_set("JustQuack", Class.new)

      delivery = DeliveryTesting.const_set(
        "MyDelivery", Class.new(described_class) { quack quack_class }
      )

      expect(delivery.quack_class).to be_eql(quack_class)
    end

    it "return nil when quack is not found" do
      delivery = DeliveryTesting.const_set("MyDelivery", Class.new(described_class))
      expect(delivery.quack_class).to be_nil
    end
  end

  context "notifications" do
    let!(:quack_class) do
      DeliveryTesting.const_set(
        "MyQuack",
        Class.new do
          class << self
            def do_something
              Quack.new "do_something"
            end

            private

            def do_nothing
            end
          end
        end
      )
    end

    describe ".notify" do
      it "calls quack_later" do
        expect { delivery_class.notify(:do_something) }.
          to raise_error(/do_something will be quacked later/)
      end

      it "do nothing when line doesn't have public method" do
        delivery_class.notify(:do_nothing)
      end
    end

    describe ".notify!" do
      it "calls quack_quack" do
        expect { delivery_class.notify!(:do_something) }.
          to raise_error(/Quack do_something!/)
      end
    end
  end

  describe ".with" do
    let!(:quack_class) do
      DeliveryTesting.const_set(
        "MyQuack",
        Class.new do
          class << self
            attr_accessor :params

            def with(**params)
              Class.new(self).tap do |clazz|
                clazz.params = params
              end
            end

            def do_something
              Quack.new "do_something with #{params[:id]} and #{params[:name]}"
            end
          end
        end
      )
    end

    it "calls with on line class" do
      expect { delivery_class.with(id: 15, name: "Maldyak").notify(:do_something) }.
        to raise_error(/do_something with 15 and Maldyak will be quacked later/)
    end
  end

  describe "callbacks" do
    let!(:quack_class) do
      DeliveryTesting.const_set(
        "MyQuack",
        Class.new do
          class << self
            attr_accessor :params

            attr_writer :calls

            def calls
              @calls ||= []
            end

            def with(**params)
              Class.new(self).tap do |clazz|
                clazz.params = params
                clazz.calls = calls
              end
            end

            def do_something
              calls << "do_something"
              Quack.new
            end

            def do_anything
              calls << "do_anything"
              Quack.new
            end
          end
        end
      )
    end

    let!(:quackkk_class) do
      DeliveryTesting.const_set(
        "MyQuackkk",
        Class.new do
          class << self
            attr_accessor :params

            attr_writer :calls

            def calls
              @calls ||= []
            end

            def with(**params)
              Class.new(self).tap do |clazz|
                clazz.params = params
                clazz.calls = calls
              end
            end

            def do_something
              calls << "do_do_something"
              Quack.new
            end

            def do_anything
              calls << "do_do_anything"
              Quack.new
            end
          end
        end
      )
    end

    let(:delivery_class) do
      DeliveryTesting.const_set(
        "MyDelivery",
        Class.new(described_class) do
          before_notify :ensure_id_positive
          before_notify :ensure_duck_present, on: :quack

          def ensure_id_positive
            params[:id] > 0
          end

          def ensure_duck_present
            params[:duck].present?
          end
        end
      )
    end

    specify "when callbacks pass" do
      delivery_class.with(id: 15, duck: "Donald").notify(:do_something)
      expect(quack_class.calls).to eq(["do_something"])
      expect(quackkk_class.calls).to eq(["do_do_something"])
    end

    specify "when both callbacks do not pass" do
      delivery_class.with(id: 0, duck: "Donald").notify(:do_something)
      expect(quack_class.calls).to eq([])
      expect(quackkk_class.calls).to eq([])
    end

    specify "when specified line option do not pass" do
      delivery_class.with(id: 10).notify(:do_something)
      expect(quack_class.calls).to eq([])
      expect(quackkk_class.calls).to eq(["do_do_something"])
    end
  end
end
