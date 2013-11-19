require 'logger'
require 'eventmachine'

require 'cocaine/dispatcher'
require 'cocaine/decoder'
require 'cocaine/protocol'


class Cocaine::Connection < EventMachine::Connection
  attr_reader :state

  def initialize(decoder=nil)
    @decoder = decoder || Cocaine::Decoder.new
    @state = :connecting
    @hooks = {
        connected: Proc.new {},
        disconnected: Proc.new {}
    }
  end

  def connection_completed
    @state = :connected
    @hooks[@state].call
  end

  def unbind
    @state = :disconnected
    @hooks[@state].call error?
  end

  def hooks(type, &block)
    @hooks[type] = block
  end

  def on_message(&block)
    @on_message = block
  end

  def receive_data(raw_data)
    @decoder.feed(raw_data) do |id, session, data|
      message = Cocaine::ProtocolFactory.create(id, data)
      $log.debug "received: [#{session}] #{message}"
      @on_message.call session, message
    end
  end
end