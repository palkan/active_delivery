# frozen_string_literal: true

module ActiveDelivery
  module TestHelper
    def assert_deliveries(count)
      TestDelivery.enable { yield }

      assert_equal TestDelivery.store.count, count, "Expected #{count} deliveries, got #{TestDelivery.store.count}"
    end

    def assert_no_deliveries(&) = assert_deliveries(0, &)

    def assert_delivery_enqueued(delivery_class, event, count: 1, params: nil, with: nil)
      TestDelivery.enable { yield }

      deliveries = TestDelivery.store

      if with
        args = with
        kwargs = args.pop if args.last.is_a?(Hash)
      end

      matching_deliveries, _unmatching_deliveries =
        deliveries.partition do |(delivery, options)|
          next false if delivery_class != delivery.owner.class

          next false if event != delivery.notification

          next false if params && !hash_include?(delivery.owner.params, params)

          next true unless with

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

      assert_equal count, matching_deliveries.count, "Expected #{count} deliveries, got #{deliveries.count}"
    end

    private

    def hash_include?(haystack, needle)
      needle.all? do |k, v|
        haystack.key?(k) && haystack[k] == v
      end
    end
  end
end
