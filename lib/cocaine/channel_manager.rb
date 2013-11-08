require 'cocaine/channel'
require 'cocaine/namespace'

class Cocaine::ChannelManager
  def initialize
    @counter = 0
    @channels = {}
  end

  def create
    @counter += 1
    channel = @channels[@counter] = Cocaine::Channel.new
    [@counter, channel]
  end

  def [](session)
    @channels[session]
  end
end