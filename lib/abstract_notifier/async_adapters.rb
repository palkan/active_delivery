# frozen_string_literal: true

module AbstractNotifier
  module AsyncAdapters
    class << self
      def lookup(adapter, options = nil)
        return adapter unless adapter.is_a?(Symbol)

        adapter_class_name = adapter.to_s.split("_").map(&:capitalize).join
        AsyncAdapters.const_get(adapter_class_name).new(**(options || {}))
      rescue NameError => e
        raise e.class, "Notifier async adapter :#{adapter} haven't been found", e.backtrace
      end
    end
  end
end
