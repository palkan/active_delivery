require "active_delivery/version"
require "active_delivery/base"
require "active_delivery/callbacks" if defined?(ActiveSupport)

require "active_delivery/lines/base"
require "active_delivery/lines/mailer" if defined?(ActionMailer)

require "active_delivery/testing" if ENV["RACK_ENV"] == "test" || ENV["RAILS_ENV"] == "test"
