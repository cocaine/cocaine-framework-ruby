require 'cocaine/future'

class Cocaine::ChannelCombiner
  def initialize(channel)
    channel.callback { |result|
      @callback.call Cocaine::Future.value result if @callback
    }
    channel.errback { |err|
      @callback.call Cocaine::Future.error err if @callback
    }
  end

  def callback(&block)
    @callback = block
  end
end