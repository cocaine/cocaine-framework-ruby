require 'logger'
require 'msgpack'
require 'optparse'

require 'celluloid'
require 'celluloid/io'

module Cocaine
  class Meta
    def metaclass
      class << self
        self
      end
    end
  end

  module Default
    module Locator
      HOST = 'localhost'
      PORT = 10053
      API = {
          0 => [
              'resolve',
              {},
              {
                  0 => ['write', nil, {}],
                  1 => ['error', {}, {}],
                  2 => ['close', {}, {}]
              }
          ]
      }
    end
  end

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

      def <<(payload)
        @queue << payload
      end

      def read(timeout=5.0)
        @queue.receive timeout
      end
    end

    class TxStream
      def initialize(session, socket)
        @session = session
        @socket = socket
      end

      def write(*payload)
        @socket.write MessagePack.pack [@session, RPC::CHUNK, payload]
      end

      def error(errno, reason)
        @socket.write MessagePack.pack [@session, RPC::ERROR, [errno, reason]]
      end

      def close
        @socket.write MessagePack.pack [@session, RPC::CHOKE, []]
      end
    end
  end

  class RxChannel
    def initialize(tree)
      @tree = Hash.new
      @queue = Celluloid::Mailbox.new

      tree.each do |id, (method, txtree, rxtree)|
        LOG.debug "Defined '#{method}' method for receive channel"
        @tree[id] = txtree
      end
    end

    # Called, when the client received a message from the runtime.
    def accept(id, payload)
      txtree = @tree[id]
      if txtree
        if txtree.empty?
          LOG.debug "Closing RX channel #{self}"
        end
      end

      @queue << [id, payload]
    end

    def get(timeout=1.0)
      @queue.receive timeout
    end
  end

  class TxChannel
    def initialize(tree, session, service)
      @session = session
      @service = service
    end

    # Called by used (implicitly via dynamically named methods), when he/she wants to send message to the session.
    def push(id, *args)
      @service.push @session, id, *args
      # TODO: Complete.
      # Traverse the tree.
      # If new state - delete old methods for service.
      # Create message.
      # Push message.
    end
  end

  class DefinedService < Meta
    include Celluloid::IO

    def initialize(name, endpoint, dispatch)
      @name = name
      @endpoint = endpoint
      @dispatch = dispatch

      @counter = 1
      @sessions = Hash.new

      host, port = endpoint
      LOG.debug "Initializing '#{name}' service at '#{host}:#{port}'"
      dispatch.each do |id, (method, txtree, rxtree)|
        LOG.debug "Defined '#{method}' method for service #{self}"
        self.metaclass.send(:define_method, method) do |*args|
          LOG.debug "Invoking #{@name}.#{method}(#{args})"
          return invoke(id, *args)
        end
      end

      addrinfo = Addrinfo.getaddrinfo(host, nil, nil, :STREAM)
      LOG.debug "Connecting to the '#{name}' service at '#{host}:#{port}'"
      addrinfo.each do |addr|
        begin
          LOG.debug "Trying: #{addr.inspect}"
          @socket = TCPSocket.new(addr.ip_address, port)
          break
        rescue IOError => err
          LOG.warn "Failed: #{err}"
        end
      end

      async.run
    end

    def run
      LOG.debug "Service '#{@name}' is running"
      unpacker = MessagePack::Unpacker.new
      loop do
        data = @socket.readpartial(4096)
        unpacker.feed_each(data) do |decoded|
          received *decoded
        end
      end
    end

    def received(session, id, payload)
      LOG.debug "<- [#{session}, #{id}, #{payload}]"
      tx, rx = @sessions[session]
      if rx
        rx.accept id, payload
      else
        LOG.warn "Received message to closed session: [#{session}, #{id}, #{payload}]"
      end
    end

    def invoke(id, *args)
      LOG.debug "Invoking #{@name}[#{id}] with #{args}"
      method, txtree, rxtree = @dispatch[id]
      tx, rx = @sessions[@counter] = [TxChannel.new(txtree, @counter, self), (RxChannel.new rxtree)]

      LOG.debug "-> [#{@counter}, #{id}, #{args}]"
      message = MessagePack.pack([@counter, id, args])
      @counter += 1

      @socket.write message
      return tx, rx
    end

    def push(session, id, *args)
      LOG.debug "Pushing #{@name}[#{id}] with #{args}"
      LOG.debug "-> [#{session}, #{id}, #{args}]"
      @socket.write MessagePack.pack([session, id, args])
    end
  end

  class Locator < DefinedService
    def initialize(host=nil, port=nil)
      super :locator, [host || Default::Locator::HOST, port || Default::Locator::PORT], Default::Locator::API
    end
  end

  class ServiceError < IOError
  end

  class Service < DefinedService
    def initialize(name, host=nil, port=nil)
      locator = Locator.new host, port
      tx, rx = locator.resolve name
      id, payload = rx.get
      if id == 1
        raise ServiceError.new payload
      end

      endpoint, version, dispatch = payload
      super name, endpoint, dispatch
    end
  end

  class WorkerActor
    include Celluloid

    def initialize(block)
      @block = block
    end

    def execute(tx, rx)
      @block.call tx, rx
    end
  end

  class Worker
    include Celluloid
    include Celluloid::IO

    execute_block_on_receiver :on
    finalizer :finalize

    def initialize(app, uuid, endpoint)
      @app = app
      @uuid = uuid
      @endpoint = endpoint
      @actors = Hash.new
      @sessions = Hash.new
    end

    def on(event, &block)
      @actors[event.to_s] = WorkerActor.new block
    end

    def run
      LOG.debug "Starting worker '#{@app}' with uuid '#{@uuid}' ad '#{@endpoint}'"
      @socket = UNIXSocket.open(@endpoint)
      async.handshake
      async.health
      async.serve
    end

    private
    def handshake
      @socket.write MessagePack::pack([1, RPC::HANDSHAKE, [@uuid]])
    end

    def health
      heartbeat = MessagePack::pack([1, RPC::HEARTBEAT, []])
      loop do
        @socket.write heartbeat
        sleep 10.0
      end
    end

    def serve
      unpacker = MessagePack::Unpacker.new
      loop do
        data = @socket.readpartial(4096)
        unpacker.feed_each(data) do |decoded|
          async.received *decoded
        end
      end
    end

    def received(session, id, payload)
      case id
        when RPC::HANDSHAKE
        when RPC::HEARTBEAT
        when RPC::TERMINATE
          terminate *payload
        when RPC::INVOKE
          invoke session, *payload
        when RPC::CHUNK, RPC::ERROR, RPC::CHOKE
          push session, *payload
        else
          LOG.warn "Received unknown message: [#{session}, #{id}, #{payload}]"
      end
    end

    def invoke(session, event)
      actor = @actors[event]
      if actor
        tx = RPC::TxStream.new(session, @socket)
        rx = RPC::RxStream.new
        @sessions[session] = [tx, rx]
        actor.execute tx, rx
      else
        LOG.warn "Received unregistered invocation event: '#{event}'"
      end
    end

    def push(session, *payload)
      _, rx = @sessions[session]
      rx << payload if rx
    end

    def terminate(errno, reason)
      LOG.warn "Terminating [#{errno}]: #{reason}"
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