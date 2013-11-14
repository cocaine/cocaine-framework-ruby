require 'cocaine/dispatcher'
require 'cocaine/asio/channel/manager'

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
    channel
  end

  protected
  def process(session, message)
    channel = @channels[session]
    case message.id
      when RPC::CHUNK
        channel.trigger unpack_chunk message.data
      when RPC::ERROR
        channel.error [message.errno, message.reason]
      when RPC::CHOKE
        channel.error message
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