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
