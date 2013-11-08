require 'protocol'
require 'cocaine/health'
require_relative '../channel_manager'

$log = Logger.new(STDERR)
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
    raise NotImplementedError
  end
end


class Cocaine::ClientDispatcher < Cocaine::Dispatcher
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


class Cocaine::Request
  def initialize(channel)
    @channel = channel
  end

  def read
    @channel
  end
end


class Cocaine::Response
  def write(data)
  end

  def close
  end
end


class Cocaine::WorkerDispatcher < Cocaine::Dispatcher
  def initialize(worker, conn)
    super conn
    @worker = worker
    @health = Cocaine::HealthManager.new self
    @health.start

    #@warn: this is weird!
    @ch = {}
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
        @ch[session] = channel
        @worker.invoke(message.event, request, response)
      when RPC::CHUNK
        df = @ch[session]
        df.trigger message.data
      when RPC::ERROR
        df = @ch[session]
        df.error message.reason
      when RPC::CHOKE
        df = @ch.delete(session)
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