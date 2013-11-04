require 'logger'
require 'eventmachine'

require 'cocaine/dispatcher'
require 'decoder'
require 'namespace'
require 'protocol'


class Cocaine::Connection < EventMachine::Connection
  attr_reader :state

  def initialize(decoder=nil)
    @decoder = decoder || Cocaine::Decoder.new
    @state = :connecting
  end

  def post_init
    @state = :connected
  end

  def on_message(&block)
    @on_message = block
  end

  def receive_data(raw_data)
    @decoder.feed(raw_data) do |id, session, data|
      message = Cocaine::ProtocolFactory.create(id, data)
      $log.debug "received: #{message}"
      @on_message.call session, message
    end
  end
end