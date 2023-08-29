# frozen_string_literal: true

# rubocop:disable Lint/ConstantDefinitionInBlock
describe ActiveDelivery::Base do
  before(:all) do
    ActiveDelivery::Base.register_line :quack, QuackLine
    ActiveDelivery::Base.register_line :quack_quack, QuackLine, suffix: "Quackkk"
    ActiveDelivery::Base.register_line :quacky, ActiveDelivery::Lines::Base, resolver_pattern: "%{delivery_namespace}Quacky%{delivery_name}"
  end

  before do
    module ::DeliveryTesting; end
  end

  after do
    Object.send(:remove_const, :DeliveryTesting)
  end

  after(:all) do
    ActiveDelivery::Base.unregister_line :quack
    ActiveDelivery::Base.unregister_line :quack_quack
  end

  let(:delivery_class) do
    DeliveryTesting.const_set(:MyDelivery, Class.new(described_class))
  end

  describe ".<line>_class" do
    it "infers class from delivery name" do
      delivery = DeliveryTesting.const_set(:MyDelivery, Class.new(described_class))

      quack_class = DeliveryTesting.const_set(:MyQuack, Class.new)

      expect(delivery.quack_class).to be_eql(quack_class)
    end

    it "infers quack from superclass" do
      delivery = DeliveryTesting.const_set(:MyDelivery, Class.new(described_class))
      quack_class = DeliveryTesting.const_set(:ParentQuack, Class.new)

      expect(delivery.quack_class).to be_nil

      parent_delivery = DeliveryTesting.const_set(:ParentDelivery, Class.new(described_class))
      sub_delivery = DeliveryTesting.const_set(:SubDelivery, Class.new(parent_delivery))

      expect(sub_delivery.quack_class).to be_eql(quack_class)
    end

    it "infers line class from pattern" do
      delivery = DeliveryTesting.const_set(:SomeDelivery, Class.new(described_class))
      quacky_class = DeliveryTesting.const_set(:QuackySome, Class.new)

      expect(delivery.quacky_class).to be_eql(quacky_class)
    end

    it "uses explicit quack" do
      quack_class = DeliveryTesting.const_set(:JustQuack, Class.new)

      delivery = DeliveryTesting.const_set(
        :MyDelivery, Class.new(described_class) { quack(quack_class) }
      )

      expect(delivery.quack_class).to be_eql(quack_class)
    end

    it "return nil when quack is not found" do
      delivery = DeliveryTesting.const_set(:MyDelivery, Class.new(described_class))
      expect(delivery.quack_class).to be_nil
    end

    context "with abstract deliveries" do
      it "always return nil for abstract deliveries", :aggregate_failures do
        delivery = DeliveryTesting.const_set(:MyDelivery, Class.new(described_class) { self.abstract_class = true })
        DeliveryTesting.const_set(:MyQuack, Class.new)
        DeliveryTesting.const_set(:ParentQuack, Class.new)

        expect(delivery.quack_class).to be_nil

        parent_delivery = DeliveryTesting.const_set(:ParentDelivery, Class.new(described_class) { self.abstract_class = true })
        sub_delivery = DeliveryTesting.const_set(:SubDelivery, Class.new(parent_delivery))

        expect(sub_delivery.quack_class).to be_nil
      end
    end
  end

  context "notifications" do
    let!(:quack_class) do
      DeliveryTesting.const_set(
        :MyQuack,
        Class.new do
          class << self
            def do_something
              Quack.new "do_something"
            end

            def do_another_thing(word:)
              Quack.new word
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
        expect { delivery_class.notify(:do_something) }
          .to raise_error(/do_something will be quacked later/)
      end

      it "do nothing when line doesn't have public method" do
        delivery_class.notify(:do_nothing)
      end

      it "supports kwargs" do
        expect { delivery_class.notify(:do_another_thing, word: "krya") }
          .to raise_error(/krya will be quacked later/)
      end
    end

    describe ".notify!" do
      it "calls quack_quack" do
        expect { delivery_class.notify!(:do_something) }
          .to raise_error(/Quack do_something!/)
      end

      it "supports kwargs" do
        expect { delivery_class.notify!(:do_another_thing, word: "krya") }
          .to raise_error(/Quack krya!/)
      end
    end

    context "when .deliver_actions_required is true" do
      around do |ex|
        was_val = ActiveDelivery.deliver_actions_required
        ActiveDelivery.deliver_actions_required = true
        ex.run
        ActiveDelivery.deliver_actions_required = was_val
      end

      it "raises NoMethodError" do
        expect { delivery_class.do_something.deliver_later }
          .to raise_error(NoMethodError)
      end

      context "when action is specified via #delivers" do
        before do
          delivery_class.delivers :do_something
        end

        it "calls quack_later" do
          expect { delivery_class.do_something.deliver_later }
            .to raise_error(/do_something will be quacked later/)
        end
      end
    end
  end

  describe ".unregister_line" do
    it "removes the line indicated by the line_id argument" do
      expect(delivery_class.delivery_lines.keys).to include(:quack_quack)

      delivery_class.unregister_line :quack_quack

      expect(delivery_class.delivery_lines.keys).not_to include(:quack_quack)
    end

    it "does not raise an error if the line does not exist" do
      expect { delivery_class.unregister_line(:what_does_the_fox_say) }.not_to raise_error
    end

    context "when unregister_line on the class that registered the line the first time" do
      it "unsets the <line>_class method" do
        delivery_class = DeliveryTesting.const_set(:MyDelivery, Class.new(described_class))

        expect(delivery_class.respond_to?(:quack_quack_class)).to be true
        expect(delivery_class.respond_to?(:quack_quack)).to be true

        delivery_class.unregister_line :quack_quack

        expect(delivery_class.respond_to?(:quack_quack_class)).to be false
        expect(delivery_class.respond_to?(:quack_quack)).to be false

        expect(ActiveDelivery::Base.respond_to?(:quack_quack_class)).to be true
        expect(ActiveDelivery::Base.respond_to?(:quack_quack)).to be true
      end
    end
  end

  describe ".with" do
    let!(:quack_class) do
      DeliveryTesting.const_set(
        :MyQuack,
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
      expect { delivery_class.with(id: 15, name: "Maldyak").do_something.deliver_later }
        .to raise_error(/do_something with 15 and Maldyak will be quacked later/)
    end
  end

  describe "callbacks", skip: !defined?(ActiveSupport) do
    let!(:quack_class) do
      DeliveryTesting.const_set(
        :MyQuack,
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
        :MyQuackkk,
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
        :MyDelivery,
        Class.new(described_class) do
          class << self
            attr_writer :calls

            def calls
              @calls ||= []
            end
          end

          before_notify :ensure_id_positive, :ensure_id_less_than_42
          before_notify :ensure_duck_present, on: :quack

          after_notify :launch_fireworks, on: :quack, only: %i[do_something]
          after_notify :feed_duck, except: %i[do_something]
          after_notify :hug_duck, if: :happy_mood?

          def ensure_id_positive = params[:id] > 0

          def ensure_id_less_than_42 = params[:id] < 42

          def ensure_duck_present = params[:duck].present?

          def launch_fireworks
            self.class.calls << "launch_fireworks"
          end

          def feed_duck
            self.class.calls << "feed_duck"
          end

          def happy_mood? = params[:id] == 5

          def hug_duck
            self.class.calls << "hug_duck"
          end
        end
      )
    end

    specify "when callbacks pass" do
      delivery_calls = []
      delivery_class.with(id: 15, duck: "Donald").notify(:do_something)
      expect(delivery_class.calls).to eq(delivery_calls << "launch_fireworks")

      expect(quack_class.calls).to eq(["do_something"])
      expect(quackkk_class.calls).to eq(["do_do_something"])

      delivery_class.with(id: 15, duck: "Donald").notify(:do_anything)
      expect(delivery_class.calls).to eq(delivery_calls << "feed_duck")

      delivery_class.with(id: 5, duck: "Donald").notify(:do_something)
      expect(delivery_class.calls).to eq(delivery_calls + %w[launch_fireworks hug_duck])
    end

    specify "when both callbacks do not pass" do
      delivery_class.with(id: 0, duck: "Donald").notify(:do_something)
      expect(quack_class.calls).to eq([])
      expect(quackkk_class.calls).to eq([])

      delivery_class.with(id: 42, duck: "Donald").notify(:do_something)
      expect(quack_class.calls).to eq([])
      expect(quackkk_class.calls).to eq([])
    end

    specify "when specified line option do not pass" do
      delivery_class.with(id: 10).notify(:do_something)
      expect(quack_class.calls).to eq([])
      expect(quackkk_class.calls).to eq(["do_do_something"])
    end

    describe "#notification_name" do
      let(:delivery_class) do
        DeliveryTesting.const_set(
          :MyDelivery,
          Class.new(described_class) do
            class << self
              attr_accessor :last_notification
            end

            after_notify do
              self.class.last_notification = notification_name
            end
          end
        )
      end

      specify do
        delivery_class.with(id: 10).notify(:do_something)
        expect(delivery_class.last_notification).to eq :do_something

        delivery_class.with(id: 10).notify(:do_anything)
        expect(delivery_class.last_notification).to eq :do_anything
      end
    end

    describe "#skip_{after,before}_notify", :aggregate_failures do
      let(:skipped_class) do
        Class.new(delivery_class) do
          quack DeliveryTesting::MyQuack

          skip_before_notify :ensure_id_positive
          skip_after_notify :launch_fireworks, on: :quack
        end
      end

      specify do
        skipped_class.with(id: 0, duck: "Donald").notify(:do_something)
        expect(quack_class.calls).to eq(["do_something"])
        expect(delivery_class.calls).to eq([])
      end
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
