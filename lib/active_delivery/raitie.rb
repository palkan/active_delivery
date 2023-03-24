# frozen_string_literal: true

module ActiveDelivery
  class Railtie < Rails::Railtie
    config.after_initialize do |app|
      ActiveDelivery.cache_classes = app.config.cache_classes
    end
  end
end
