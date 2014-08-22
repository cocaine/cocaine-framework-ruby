require 'optparse'

require 'celluloid'
require 'celluloid/io'

module Cocaine
  module RPC
    HANDSHAKE = 0
    HEARTBEAT = 1
    TERMINATE = 2
    INVOKE = 3
    CHUNK = 4
    ERROR = 5
    CHOKE = 6

    class RxStream
      def initialize
        @queue = Celluloid::Mailbox.new
      end

      def accept(payload)
        LOG.debug "Put '#{payload}'"
        @queue << payload
      end

      def read(timeout=10.0)
        LOG.debug 'Get...'
        payload = @queue.receive timeout
        LOG.debug "GOT '#{payload}'"
        payload
      end
    end

    class TxStream
      def initialize(session, socket)
        @session = session
        @socket = socket
      end

      def write(id, *payload)
        LOG.debug "Write to socket: [#{@session}, #{id}, #{payload}]"
        @socket.write MessagePack.pack [@session, id, payload]
      end
    end
  end

  class Worker
    include Celluloid
    include Celluloid::IO

    finalizer :finalize

    def initialize(app, uuid, endpoint)
      @app = app
      @uuid = uuid
      @endpoint = endpoint
      @events = Hash.new
      @sessions = Hash.new
    end

    # execute_block_on_receiver :on
    def on(event, block)
      @events[event.to_s] = block
    end

    def run
      LOG.debug "Starting worker '#{@app}' with uuid '#{@uuid}'"
      LOG.debug "Connecting to the '#{@endpoint}'"
      @socket = UNIXSocket.open(@endpoint)
      async.handshake
      async.health
      async.serve
    end

    def handshake
      @socket.write MessagePack::pack([1, RPC::HANDSHAKE, [@uuid]])
    end

    def health
      loop do
        @socket.write MessagePack::pack([1, RPC::HEARTBEAT, []])
        sleep 10.0
      end
    end

    def serve
      unpacker = MessagePack::Unpacker.new
      loop do
        data = @socket.readpartial(4096)
        unpacker.feed_each(data) do |decoded|
          received *decoded
        end
      end
    end

    def received(session, id, payload)
      case id
        when RPC::HANDSHAKE
          # Todo.
        when RPC::HEARTBEAT
          # Todo.
        when RPC::TERMINATE
          # Todo.
        when RPC::INVOKE
          invoke session, *payload
        when RPC::CHUNK, RPC::ERROR, RPC::CHOKE
          push session, id, *payload
        else
          LOG.warn "Received unknown message: [#{session}, #{id}, #{payload}]"
          # type code here
      end
    end

    def invoke(session, event)
      LOG.debug "Invoking '#{event}' event"
      callback = @events[event]
      if callback
        tx = RPC::TxStream.new(session, @socket)
        rx = RPC::RxStream.new
        @sessions[session] = [tx, rx]
        Celluloid::Future.new { callback.exec tx, rx }
        # f.value
      else
        LOG.warn "Received unregistered invocation event: '#{event}'"
      end
    end

    def push(session, id, *payload)
      LOG.debug "Pushing #{session}, #{id}: #{payload}"
      tx, rx = @sessions[session]
      if rx
        rx.accept payload
      end
    end

    def terminate(errno, reason)
      exit(errno)
    end

    def finalize
      if @socket
        @socket.close
      end
    end
  end

  class WorkerFactory
    def self.create
      options = {}
      OptionParser.new do |opts|
        opts.banner = 'Usage: <your_worker.rb> --app NAME --locator ADDRESS --uuid UUID --endpoint ENDPOINT'

        opts.on('--app NAME', 'Worker name') { |a| options[:app] = a }
        opts.on('--locator ADDRESS', 'Locator address') { |a| options[:locator] = a }
        opts.on('--uuid UUID', 'Worker uuid') { |a| options[:uuid] = a }
        opts.on('--endpoint ENDPOINT', 'Worker endpoint') { |a| options[:endpoint] = a }
      end.parse!
      return Worker.new(options[:app], options[:uuid], options[:endpoint])
    end
  end
end
