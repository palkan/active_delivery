# frozen_string_literal: true

# rubocop:disable Lint/ConstantDefinitionInBlock
describe "RSpec matcher" do
  before(:all) do
    ActiveDelivery::Base.register_line :testo, ActiveDelivery::Lines::Base
  end

  before(:all) do
    module ::DeliveryTesting
      class Sender
        class << self
          alias_method :with, :new

          def send_something(...)
            new.send_something(...)
          end
        end

        def initialize(*)
        end

        def send_something(*)
        end
      end

      class Delivery < ActiveDelivery::Base
        testo Sender
      end
    end
  end

  after(:all) do
    Object.send(:remove_const, :DeliveryTesting)
  end

  let(:delivery) { ::DeliveryTesting::Delivery }

  context "success" do
    specify "with only delivery class" do
      expect { delivery.send_something("data", 42).deliver_later }
        .to have_delivered_to(delivery)
    end

    specify "with #deliver_now" do
      expect { delivery.send_something("data", 42).deliver_now }
        .to have_delivered_to(delivery).synchronously
    end

    specify "with delivery class and arguments" do
      expect { delivery.notify(:send_something, "data", 42) }
        .to have_delivered_to(delivery, :send_something, a_string_matching(/da/), 42)
    end

    specify "with times" do
      expect { delivery.notify(:send_something, "data", 42) }
        .to have_delivered_to(delivery).once
    end

    specify "when multiple times" do
      expect do
        delivery.notify(:send_something, "data", 42)
        delivery.notify(:send_something, "data", 45)
      end.to have_delivered_to(delivery).twice
        .and have_delivered_to(delivery, :send_something, "data", 42).once
        .and have_delivered_to(delivery, :send_something, "data", 45).once
    end

    specify "with params" do
      expect { delivery.with(id: 42).notify(:send_something, "data") }
        .to have_delivered_to(delivery, :send_something, "data").with(id: 42)
    end

    context "negatiation" do
      specify "not_to" do
        expect { true }.not_to have_delivered_to(delivery)
      end

      specify "have_not_delivered_to" do
        expect { true }.to have_not_delivered_to(delivery)
      end
    end
  end

  context "failure" do
    specify "when no delivery was made" do
      expect do
        expect { true }
          .to have_delivered_to(delivery)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    specify "with wrong action" do
      expect do
        expect { delivery.notify(:send_something) }
          .to have_delivered_to(delivery, :send_smth)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    specify "with wrong arguments" do
      expect do
        expect { delivery.notify(:send_something, "fail") }
          .to have_delivered_to(delivery, :send_something, "foil")
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    specify "with wrong params" do
      expect do
        expect { delivery.with(id: 13).notify(:send_something) }
          .to have_delivered_to(delivery, :send_something).with(id: 31)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    specify "with wrong number of times" do
      expect do
        expect { delivery.notify(:send_something) }
          .to have_delivered_to(delivery, :send_something).twice
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  context "fibers" do
    specify "success" do
      expect { Fiber.new { delivery.notify(:send_something, "data", 42) }.resume }
        .to have_delivered_to(delivery)
    end

    specify "failure" do
      expect do
        expect { Fiber.new { delivery.notify(:send_something) }.resume }
          .to have_delivered_to(delivery, :send_smth)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
