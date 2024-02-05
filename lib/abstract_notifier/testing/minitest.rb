# frozen_string_literal: true

module AbstractNotifier
  module TestHelper
    def assert_notifications_sent(count, params)
      yield
      assert_equal deliveries.count, count
      count.times do |i|
        delivery = deliveries[0 - i]
        if !params[:via]
          delivery = delivery.dup
          delivery.delete(:via)
        end

        msg = message(msg) { "Expected #{mu_pp(delivery)} to include #{mu_pp(params)}" }
        assert hash_include?(delivery, params), msg
      end
    end

    def assert_notifications_enqueued(count, params)
      yield
      assert_equal count, enqueued_deliveries.count
      count.times do |i|
        delivery = enqueued_deliveries[0 - i]
        if !params[:via]
          delivery = delivery.dup
          delivery.delete(:via)
        end

        msg = message(msg) { "Expected #{mu_pp(delivery)} to include #{mu_pp(params)}" }
        assert hash_include?(delivery, params), msg
      end
    end

    private

    def deliveries
      AbstractNotifier::Testing::Driver.deliveries
    end

    def enqueued_deliveries
      AbstractNotifier::Testing::Driver.enqueued_deliveries
    end

    def hash_include?(haystack, needle)
      needle.all? do |k, v|
        haystack.key?(k) && haystack[k] == v
      end
    end
  end
end
