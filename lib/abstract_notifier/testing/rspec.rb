# frozen_string_literal: true

module AbstractNotifier
  class HaveSentNotification < RSpec::Matchers::BuiltIn::BaseMatcher
    attr_reader :payload

    def initialize(payload = nil)
      @payload = payload
      set_expected_number(:exactly, 1)
    end

    def exactly(count)
      set_expected_number(:exactly, count)
      self
    end

    def at_least(count)
      set_expected_number(:at_least, count)
      self
    end

    def at_most(count)
      set_expected_number(:at_most, count)
      self
    end

    def times
      self
    end

    def once
      exactly(:once)
    end

    def twice
      exactly(:twice)
    end

    def thrice
      exactly(:thrice)
    end

    def supports_block_expectations?
      true
    end

    def matches?(proc)
      raise ArgumentError, "have_sent_notification only supports block expectations" unless Proc === proc

      raise "You can only use have_sent_notification matcher in :test delivery mode" unless AbstractNotifier.test?

      original_deliveries_count = deliveries.count
      proc.call
      in_block_deliveries = deliveries.drop(original_deliveries_count)

      @matching_deliveries, @unmatching_deliveries =
        in_block_deliveries.partition do |actual_payload|
          next true if payload.nil?

          if payload.is_a?(::Hash) && !payload[:via]
            actual_payload = actual_payload.dup
            actual_payload.delete(:via)
          end

          payload === actual_payload
        end

      @matching_count = @matching_deliveries.size

      case @expectation_type
      when :exactly then @expected_number == @matching_count
      when :at_most then @expected_number >= @matching_count
      when :at_least then @expected_number <= @matching_count
      end
    end

    def deliveries
      AbstractNotifier::Testing::Driver.deliveries
    end

    def set_expected_number(relativity, count)
      @expectation_type = relativity
      @expected_number =
        case count
        when :once then 1
        when :twice then 2
        when :thrice then 3
        else Integer(count)
        end
    end

    def failure_message
      (+"expected to #{verb_present} notification: #{payload_description}").tap do |msg|
        msg << " #{message_expectation_modifier}, but"

        if @unmatching_deliveries.any?
          msg << " #{verb_past} the following notifications:"
          @unmatching_deliveries.each do |unmatching_payload|
            msg << "\n  #{unmatching_payload}"
          end
        else
          msg << " haven't #{verb_past} anything"
        end
      end
    end

    def failure_message_when_negated
      "expected not to #{verb_present} #{payload}"
    end

    def message_expectation_modifier
      number_modifier = (@expected_number == 1) ? "once" : "#{@expected_number} times"
      case @expectation_type
      when :exactly then "exactly #{number_modifier}"
      when :at_most then "at most #{number_modifier}"
      when :at_least then "at least #{number_modifier}"
      end
    end

    def payload_description
      if payload.is_a?(RSpec::Matchers::Composable)
        payload.description
      else
        payload
      end
    end

    def verb_past
      "sent"
    end

    def verb_present
      "send"
    end
  end

  class HaveEnqueuedNotification < HaveSentNotification
    private

    def deliveries
      AbstractNotifier::Testing::Driver.enqueued_deliveries
    end

    def verb_past
      "enqueued"
    end

    def verb_present
      "enqueue"
    end
  end
end

RSpec.configure do |config|
  config.include(Module.new do
    def have_sent_notification(*)
      AbstractNotifier::HaveSentNotification.new(*)
    end

    def have_enqueued_notification(*)
      AbstractNotifier::HaveEnqueuedNotification.new(*)
    end
  end)
end
