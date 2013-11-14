require 'cocaine/future'

class Cocaine::ChannelZipper
  def initialize(channel)
    @channel = channel
    @channel.callback { |result| @callback.call Cocaine::Future.value result }
    @callback = nil
  end

  def callback(&block)
    @callback = block
  end
end