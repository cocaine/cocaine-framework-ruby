require 'cocaine/client/service'
require 'cocaine/synchrony/channel'


module Cocaine::Synchrony
  def self.sync(df)
    fb = Fiber.current
    df.callback { |result| fb.resume result }
    df.errback { |err| raise ServiceError.new err }
    Fiber.yield
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

  :private
  def create_proxy_methods
    @service.api.each do |id, name|
      self.metaclass.send(:define_method, name) do |*args|
        Cocaine::Synchrony::Channel.new @service.send name, *args
      end
    end
  end
end