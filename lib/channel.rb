require 'eventmachine'

require_relative 'namespace'

class IllegalStateError < StandardError
end

class Cocaine::Channel
  def initialize
    @state = :opened

    @pending = []
    @errors = []

    @callbacks = []
    @errbacks = []
  end

  def callback(&block)
    register_callback @callbacks, @pending, block
    self
  end

  def errback(&block)
    register_callback @errbacks, @errors, block
    self
  end

  def trigger(chunk)
    do_trigger @callbacks, @pending, chunk
  end

  def error(err)
    do_trigger @errbacks, @errors, err
  end

  def close
    @state = :closed
    check_and_trigger_collector
  end

  :private
  def check_and_trigger_collector
    if @collector
      trigger_collector
    end
  end

  :private
  def trigger_collector
    if @errors.length == 1
      @collector.fail *@errors
    else
      @collector.succeed @pending.concat(@errors)
    end
  end

  def collect
    raise IllegalStateError if @state == :closed
    raise IllegalStateError.new 'only one collector can be bound to the channel' if @collector
    @collector ||= EM::DefaultDeferrable.new
  end

  :private
  def register_callback(callbacks, entities, block)
    raise IllegalStateError unless @state == :opened

    until entities.empty?
      block.call entities.pop
    end

    callbacks.push block
    self
  end

  :private
  def do_trigger(callbacks, entities, entity)
    raise IllegalStateError unless @state == :opened

    if callbacks.empty?
      entities ||= []
      entities.push entity
    else
      callbacks.each do |callback|
        callback.call entity
      end
    end
  end
end
