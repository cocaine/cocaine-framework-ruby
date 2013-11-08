require 'cocaine/channel_manager'
require 'cocaine/health'
require 'cocaine/protocol'
require 'cocaine/server/request'
require 'cocaine/server/response'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::Dispatcher
  def initialize(conn)
    @conn = conn
    @conn.on_message do |session, message|
      process session, message
    end
  end

  def process(session, message)
    raise NotImplementedError
  end
end


class Cocaine::ClientDispatcher < Cocaine::Dispatcher
  def initialize(conn)
    super conn
    @channels = Cocaine::ChannelManager.new
  end

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

  :private
  def unpack_chunk(data)
    if data.kind_of?(Array)
      data = data.join(',')
    end
    MessagePack.unpack(data)
  end
end


class Cocaine::WorkerDispatcher < Cocaine::Dispatcher
  def initialize(worker, conn)
    super conn
    @worker = worker
    @health = Cocaine::HealthManager.new self
    @health.start
    @channels = {}
  end

  def process(session, message)
    case message.id
      when RPC::HEARTBEAT
        @health.breath()
      when RPC::TERMINATE
        @worker.terminate()
      when RPC::INVOKE
        channel = Cocaine::Channel.new
        request = Cocaine::Request.new channel
        response = Cocaine::Response.new
        @channels[session] = channel
        @worker.invoke(message.event, request, response)
      when RPC::CHUNK
        df = @channels[session]
        df.trigger message.data
      when RPC::ERROR
        df = @channels[session]
        df.error message.reason
      when RPC::CHOKE
        df = @channels.delete(session)
        df.close
      else
        raise "unexpected message id: #{id}"
    end
  end

  def send_handshake(session, uuid)
    send Handshake.new(uuid), session
  end

  def send_heartbeat(session)
    send Heartbeat.new, session
  end

  def send_terminate(session, errno, reason)
    send Terminate.new(errno, reason), session
  end

  :private
  def send(message, session)
    @conn.send_data message.pack(session)
  end
end