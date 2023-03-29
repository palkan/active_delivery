# frozen_string_literal: true

class Quack
  attr_reader :mid

  def initialize(mid = nil)
    @mid = mid
  end

  def quack_later
    return if mid.nil?
    raise "#{mid} will be quacked later"
  end

  def quack_quack
    return if mid.nil?
    raise "Quack #{mid}!"
  end
end

class QuackLine < ActiveDelivery::Lines::Base
  def resolve_class(klass)
    ::DeliveryTesting.const_get(klass.name.gsub(/Delivery$/, options.fetch(:suffix, "Quack")))
  rescue
  end

  def notify_now(handler, ...)
    handler.public_send(...).quack_quack
  end

  def notify_later(handler, ...)
    handler.public_send(...).quack_later
  end
end
