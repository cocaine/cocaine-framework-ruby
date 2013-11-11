require 'fiber'
require 'em-synchrony'

require 'cocaine/namespace'
require 'cocaine/service'


class Cocaine::Synchrony::Channel
  def initialize(channel)
    @channel = channel
    @fb = Fiber.current
    @channel.callback { |result| @fb.resume result }
    @channel.errback { |err|
      if err.instance_of? Choke
      else
        raise ServiceError.new err
      end
    }

    @chunks = []
  end

  def read
    if @chunks.empty?
      Fiber.yield
    else
      @chunks.pop
    end
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