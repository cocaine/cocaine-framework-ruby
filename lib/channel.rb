require_relative 'namespace'

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
    @callbacks.each do |callback|
      until @pending.empty?
        callback.call @pending.pop
      end
    end

    @errbacks.each do |errback|
      until @errors.empty?
        errback.call @errors.pop
      end
    end
  end

  :private
  def register_callback(callbacks, entities, block)
    until entities.empty?
      block.call entities.pop
    end

    callbacks.push block
    self
  end

  :private
  def do_trigger(callbacks, entities, entity)
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
