require 'fiber'
require 'em-synchrony'

require 'cocaine/namespace'
require 'cocaine/service'


class Cocaine::Synchrony::Channel
  def initialize(channel)
    @channel = channel
    @chunks = []

    fb = Fiber.current

    @channel.callback { |result|
      if fb.alive?
        fb.resume result
      else
        @chunks.push result
      end
    }

    @channel.errback { |err|
      if fb.alive?
        if err.instance_of? Choke
          fb.resume
        else
          raise ServiceError.new err
        end
      else
        @chunks.push err
      end
    }
  end

  def read
    if @chunks.empty?
      Fiber.yield
    else
      chunk = @chunks.pop
      if chunk.instance_of? Exception
        raise chunk
      else
        chunk
      end
    end
  end

  def collect(count)
    chunks = []
    while count > 0
      chunks.push Fiber.yield
      count -= 1
    end
    chunks
  end
end


module Cocaine::Synchrony
  def self.sync(df)
    fb = Fiber.current
    df.callback { |result| fb.resume result }
    df.errback { |err| raise Exception.new err }
    Fiber.yield
  end
end


class Cocaine::Synchrony::Service
  def initialize(name)
    @service = Cocaine::Service.new name
    connect
    create_proxies
  end

  :private
  def connect
    EM::Synchrony.sync @service.connect
  end

  :private
  def create_proxies
    @service.api.each do |id, name|
      self.metaclass.send(:define_method, name) do |*args|
        Cocaine::Synchrony::Channel.new @service.send name, *args
      end
    end
  end
end