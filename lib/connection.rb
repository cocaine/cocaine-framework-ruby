require 'logger'
require 'eventmachine'

require_relative 'channel_manager'
require_relative 'namespace'
require_relative 'protocol'
require_relative 'decoder'


$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG


class Cocaine::Dispatcher
  def initialize(conn)
    @conn = conn
    @conn.on_message do |session, message|
      process session, message
    end

    @channels = Cocaine::ChannelManager.new
  end

  def process(session, message)
    # when RPC::HANDSHAKE
    # when RPC::HEARTBEAT
    # when RPC::TERMINATE
    # when RPC::INVOKE
    # when RPC::CHUNK
    # when RPC::ERROR
    # when RPC::CHOKE
  end
end


class Cocaine::ClientDispatcher < Cocaine::Dispatcher
  def process(session, message)
    channel = @channels[session]
    case message.id
      when RPC::CHUNK
        channel.trigger message.data
      when RPC::ERROR
        channel.error [message.errno, message.reason]
      when RPC::CHOKE
        channel.error message
        channel.close
      else
        raise "unexpected message id: #{id}"
    end
  end

  def invoke(method_id, *data)
    $log.debug("invoking #{method_id} with #{data}")
    session, channel = @channels.create
    message = MessagePack::pack([method_id, session, data])
    @conn.send_data message
    channel
  end
end


class Cocaine::Connection < EventMachine::Connection
  attr_reader :state

  def initialize(decoder=nil)
    @decoder = decoder || Cocaine::Decoder.new
    @state = :connecting
  end

  def post_init
    @state = :connected
  end

  def receive_data(data)
    @decoder.feed(data) do |id, session, data|
      message = Cocaine::ProtocolFactory.create(id, data)
      $log.debug "received: #{message}"
      @on_message.call session, message
    end
  end

  def on_message(&block)
    @on_message = block
  end
end