require 'logger'
require 'eventmachine'

require_relative 'channel_manager'
require_relative 'namespace'
require_relative 'protocol'
require_relative 'decoder'


$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG


class Cocaine::Connection < EventMachine::Connection
  attr_reader :state

  def initialize(decoder=nil)
    @decoder = decoder || Cocaine::Decoder.new
    @state = :connecting

    @channels = Cocaine::ChannelManager.new
  end

  def post_init
    @state = :connected
  end

  def receive_data(data)
    @decoder.feed(data) do |id, session, message|
      msg = Cocaine::ProtocolFactory.create(id, message)
      $log.debug "received: #{msg}"
      channel = @channels[session]
      case msg.id
        when RPC::CHUNK
          channel.trigger msg.data
        when RPC::ERROR
          channel.error [msg.errno, msg.reason]
        when RPC::CHOKE
          channel.error msg
          channel.close
        else
          raise "unexpected message id: #{id}"
      end
    end
  end

  def invoke(method_id, *data)
    $log.debug("invoking #{method_id} with #{data}")
    session, channel = @channels.create
    message = MessagePack::pack([method_id, session, data])
    send_data message
    channel
  end
end
