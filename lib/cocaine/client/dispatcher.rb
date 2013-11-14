require 'cocaine/asio/channel/combiner'
require 'cocaine/asio/channel/manager'
require 'cocaine/dispatcher'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::ClientDispatcher < Cocaine::Dispatcher
  def initialize(conn)
    super conn
    @channels = Cocaine::ChannelManager.new
  end

  def invoke(method_id, *data)
    $log.debug("invoking #{method_id} with #{data}")
    session, channel = @channels.create
    message = MessagePack::pack([method_id, session, data])
    @conn.send_data message
    Cocaine::ChannelCombiner.new channel
  end

  protected
  def process(session, message)
    channel = @channels[session]
    case message.id
      when RPC::CHUNK
        channel.trigger unpack_chunk message.data
      when RPC::ERROR
        channel.error ServiceError.new "[#{message.errno}] #{message.reason}"
      when RPC::CHOKE
        channel.error ChokeEvent.new
        channel.close
      else
        raise "unexpected message id: #{message.id}"
    end
  end

  private
  def unpack_chunk(data)
    if data.kind_of?(Array)
      data = data.join(',')
    end
    MessagePack.unpack(data)
  end
end