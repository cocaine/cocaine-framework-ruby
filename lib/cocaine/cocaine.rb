require 'logger'
require 'msgpack'
require 'optparse'

require 'celluloid'
require 'celluloid/io'

module Cocaine
  # For dynamic method creation. [Detail].
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
      ERROR_CODE = 1
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

    RXTREE = {
        CHUNK => ['write', nil, {}],
        ERROR => ['error', {}, {}],
        CHOKE => ['close', {}, {}]
    }
    TXTREE = RXTREE
  end

  # Base class for shared read channel state. [Detail].
  class Box
    def initialize(queue)
      @queue = queue
    end
  end

  # Read-only part for shared reader state. [API].
  class Inbox < Box
    def receive(timeout=30.0)
      @queue.receive timeout
    end
  end

  # Write-only part for shared reader state. [Detail].
  class Outbox < Box
    def initialize(queue, tree)
      super queue

      @tree = Hash.new
      tree.each do |id, (_, txtree, _)|
        @tree[id] = txtree
      end
    end

    def push(id, payload)
      txtree = @tree[id]
      if txtree && txtree.empty?
        # Todo: Close.
        LOG.debug "Closing RX channel #{self}"
      end

      @queue << [id, payload]
    end
  end

  # Shared reader state, that acts like channel. [Detail].
  class RxChannel
    attr_reader :inbox, :outbox

    def initialize(tree)
      queue = Celluloid::Mailbox.new
      @inbox = Inbox.new queue
      @outbox = Outbox.new queue, tree
    end
  end

  # Writer channel. [API].
  class TxChannel < Meta
    def initialize(tree, session, socket)
      @session = session
      @socket = socket

      tree.each do |id, (method, _, _)|
        LOG.debug "Defined '#{method}' method for tx channel"
        self.metaclass.send(:define_method, method) do |*args|
          push id, *args
        end
      end
    end

    private
    def push(id, *args)
      LOG.debug "-> [#{@session}, #{id}, #{args}]"
      @socket.write MessagePack.pack [@session, id, args]
      # TODO: Complete.
      # Traverse the tree.
      # If new state - delete old methods for service.
      # Create message.
      # Push message.
    end
  end

  # [Detail].
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
      dispatch.each do |id, (method, _, _)|
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

    private
    def run
      LOG.debug "Service '#{@name}' is running"
      unpacker = MessagePack::Unpacker.new
      loop do
        data = @socket.readpartial(4096)
        unpacker.feed_each(data) do |decoded|
          async.received *decoded
        end
      end
    end

    def received(session, id, payload)
      LOG.debug "<- [#{session}, #{id}, #{payload}]"
      _, rx = @sessions[session]
      if rx
        rx.push id, payload
      else
        LOG.warn "Received message to closed session: [#{session}, #{id}, #{payload}]"
      end
    end

    def invoke(id, *args)
      LOG.debug "Invoking #{@name}[#{id}] with #{args}"
      _, txtree, rxtree = @dispatch[id]
      tx = TxChannel.new txtree, @counter, @socket
      rx = RxChannel.new rxtree
      @sessions[@counter] = [tx, rx.outbox]

      LOG.debug "-> [#{@counter}, #{id}, #{args}]"
      message = MessagePack.pack([@counter, id, args])
      @counter += 1

      @socket.write message
      return tx, rx.inbox
    end
  end

  # [API].
  class Locator < DefinedService
    def initialize(host=nil, port=nil)
      super :locator, [host || Default::Locator::HOST, port || Default::Locator::PORT], Default::Locator::API
    end
  end

  class ServiceError < IOError
  end

  # [API].
  class Service < DefinedService
    def initialize(name, host=nil, port=nil)
      locator = Locator.new host, port
      _, rx = locator.resolve name
      id, payload = rx.receive
      if id == Default::Locator::ERROR_CODE
        raise ServiceError.new payload
      end

      endpoint, _, dispatch = payload
      super name, endpoint, dispatch
    end
  end

  # [Detail].
  class WorkerActor
    include Celluloid

    def initialize(block)
      @block = block
    end

    def execute(tx, rx)
      @block.call tx, rx
    end
  end

  # [API].
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
          push session, id, *payload
        else
          LOG.warn "Received unknown message: [#{session}, #{id}, #{payload}]"
      end
    end

    def invoke(session, event)
      actor = @actors[event]
      if actor
        tx = TxChannel.new RPC::TXTREE, session, @socket
        rx = RxChannel.new RPC::RXTREE
        @sessions[session] = [tx, rx.outbox]
        actor.execute tx, rx.inbox
      else
        LOG.warn "Received unregistered invocation event: '#{event}'"
      end
    end

    def push(session, id, *payload)
      _, rx = @sessions[session]
      if rx
        rx.push id, *payload
      end
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

  # [API].
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