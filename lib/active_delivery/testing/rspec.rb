# frozen_string_literal: true

module ActiveDelivery
  class HaveDeliveredTo < RSpec::Matchers::BuiltIn::BaseMatcher
    attr_reader :delivery_class, :event, :args, :kwargs, :params, :sync_value

    def initialize(delivery_class, event = nil, *args, **kwargs)
      @delivery_class = delivery_class
      @event = event
      @args = args
      @kwargs = kwargs
      set_expected_number(:exactly, 1)
    end

    def with(params)
      @params = params
      self
    end

    def synchronously
      @sync_value = true
      self
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
      raise ArgumentError, "have_delivered_to only supports block expectations" unless Proc === proc

      TestDelivery.enable { proc.call }

      actual_deliveries = TestDelivery.store

      @matching_deliveries, @unmatching_deliveries =
        actual_deliveries.partition do |(delivery, options)|
          next false unless delivery_class == delivery.owner.class

          next false if !sync_value.nil? && (options.fetch(:sync, false) != sync_value)

          next false unless params.nil? || params === delivery.owner.params

          next false unless event.nil? || event == delivery.notification

          actual_args = delivery.params
          actual_kwargs = delivery.options

          next false unless args.each.with_index.all? do |arg, i|
            arg === actual_args[i]
          end

          next false unless kwargs.all? do |k, v|
            v === actual_kwargs[k]
          end

          true
        end

      @matching_count = @matching_deliveries.size

      case @expectation_type
      when :exactly then @expected_number == @matching_count
      when :at_most then @expected_number >= @matching_count
      when :at_least then @expected_number <= @matching_count
      end
    end

    def failure_message
      (+"expected to deliver").tap do |msg|
        msg << " :#{event} notification" if event
        msg << " via #{delivery_class}#{sync_value ? " (sync)" : ""} with:"
        msg << "\n - params: #{params_description(params)}" if params
        msg << "\n - args: #{args.empty? ? "<none>" : args}"
        msg << "\n#{message_expectation_modifier}, but"

        if @unmatching_deliveries.any?
          msg << " delivered the following unexpected notifications:"
          msg << deliveries_description(@unmatching_deliveries)
        elsif @matching_count.positive?
          msg << " delivered #{@matching_count} matching notifications" \
                 " (#{count_failure_message}):"
          msg << deliveries_description(@matching_deliveries)
        else
          msg << " haven't delivered anything"
        end
      end
    end

    private

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

    def failure_message_when_negated
      "expected not to deliver #{event ? " :#{event} notification" : ""} via #{delivery_class}"
    end

    def message_expectation_modifier
      number_modifier = (@expected_number == 1) ? "once" : "#{@expected_number} times"
      case @expectation_type
      when :exactly then "exactly #{number_modifier}"
      when :at_most then "at most #{number_modifier}"
      when :at_least then "at least #{number_modifier}"
      end
    end

    def count_failure_message
      diff = @matching_count - @expected_number
      if diff.positive?
        "#{diff} extra item(s)"
      else
        "#{diff} missing item(s)"
      end
    end

    def deliveries_description(deliveries)
      deliveries.each.with_object(+"") do |(delivery, options), msg|
        msg << "\n  :#{delivery.notification} via #{delivery.owner.class}" \
              "#{options[:sync] ? " (sync)" : ""}" \
              " with:" \
              "\n   - params: #{delivery.owner.params.empty? ? "<none>" : delivery.owner.params.inspect}" \
              "\n   - args: #{delivery.params}" \
              "\n   - kwargs: #{delivery.options}"
      end
    end

    def params_description(data)
      if data.is_a?(RSpec::Matchers::Composable)
        data.description
      else
        data
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Module.new do
    def have_delivered_to(*args)
      ActiveDelivery::HaveDeliveredTo.new(*args)
    end
  end)
end

RSpec::Matchers.define_negated_matcher :have_not_delivered_to, :have_delivered_to
