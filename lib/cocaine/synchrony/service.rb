require 'cocaine/client/service'
require 'cocaine/synchrony/channel'


module Cocaine::Synchrony
  def self.sync(df)
    fb = Fiber.current
    df.callback do |result|
      if fb == Fiber.current
        return result
      else
        fb.resume result
      end
    end

    df.errback do |err|
      if fb == Fiber.current
        raise Cocaine::ServiceError.new err
      else
        fb.resume Cocaine::ServiceError.new err
      end
    end
    result = Fiber.yield
    if result.is_a? Exception
      raise result
    else
      return result
    end
  end
end


class Cocaine::Synchrony::Service
  def initialize(name)
    @service = Cocaine::Service.new name
    connect
    create_proxy_methods
  end

  def connect
    Cocaine::Synchrony.sync @service.connect
  end

  private
  def create_proxy_methods
    @service.api.each do |id, name|
      self.metaclass.send(:define_method, name) do |*args|
        Cocaine::Synchrony::Channel.new @service.send name, *args
      end
    end
  end
end