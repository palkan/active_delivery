# frozen_string_literal: true

require "ruby-next"
require "ruby-next/language/setup"
RubyNext::Language.setup_gem_load_path(transpile: true)

require "active_delivery/version"
require "active_delivery/base"
require "active_delivery/callbacks" if defined?(ActiveSupport)

require "active_delivery/lines/base"
require "active_delivery/lines/mailer" if defined?(ActionMailer)

require "active_delivery/raitie" if defined?(::Rails::Railtie)
require "active_delivery/testing" if ENV["RACK_ENV"] == "test" || ENV["RAILS_ENV"] == "test"
