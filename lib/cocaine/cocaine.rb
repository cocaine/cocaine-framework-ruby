require 'logger'
require 'msgpack'
require 'optparse'
require 'uri'

require 'celluloid'
require 'celluloid/io'

module Cocaine
  # [Detail]
  # For dynamic method creation.
  class Meta
    def metaclass
      class << self
        self
      end
    end
  end

  METHOD_ID = 0
  TX_TREE_ID = 1
  RX_TREE_ID = 2

  module Default
    module Locator
      def host
        @host || '::'
      end

      def host=(host)
        @host = host
      end

      def port
        @port || 10053
      end

      def port=(port)
        @port = port
      end

      module_function :host, :host=, :port, :port=

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
    HANDSHAKE, HEARTBEAT, TERMINATE, INVOKE, CHUNK, ERROR, CHOKE = (0..6).to_a

    RXTREE = {
        CHUNK => ['write', nil, {}],
        ERROR => ['error', {}, {}],
        CHOKE => ['close', {}, {}]
    }
    TXTREE = RXTREE
  end

  # [Detail]
  # Base class for shared read channel state.
  class Mailbox
    def initialize(queue)
      @queue = queue
    end
  end

  # [API]
  # Read-only part for shared reader state.
  class RxMailbox < Mailbox
    def recv(timeout=30.0)
      @queue.receive timeout
    end
  end

  # [Detail]
  # Write-only part for shared reader state.
  class TxMailbox < Mailbox
    def initialize(queue, tree)
      super queue

      @tree = Hash.new
      tree.each do |id, (method, txtree, rxtree)|
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

  # [Detail]
  # Shared reader state, that acts like channel. Need for channel splitting between the library and a user.
  class RxChannel
    attr_reader :tx, :rx

    def initialize(tree)
      queue = Celluloid::Mailbox.new
      @tx = TxMailbox.new queue, tree
      @rx = RxMailbox.new queue
    end
  end

  # [API]
  # Writer channel. Patches itself with current state, providing methods described in tx tree.
  class TxChannel < Meta
    def initialize(tree, session, socket)
      @session = session
      @socket = socket
      @tree = nil
      rebind tree
    end

    private
    def push(id, *args)
      LOG.debug "<- [#{@session}, #{id}, #{args}]"
      @socket.write MessagePack.pack [@session, id, args]
      rebind @tree[id][Cocaine::TX_TREE_ID]
    end

    def rebind(new)
      if new.nil?
        LOG.debug 'Found recursive leaf - doing nothing with tx channel'
        return
      end

      old = @tree || Hash.new
      old.each do |id, (method, txtree, rxtree)|
        LOG.debug "Removed '#{method}' method for tx channel"
        self.metaclass.send(:define_method, method) do |*|
          raise Exception.new "Method '#{method}' is removed"
        end
      end

      new ||= Hash.new
      new.each do |id, (method, txtree, rxtree)|
        LOG.debug "Defined '#{method}' method for tx channel"
        self.metaclass.send(:define_method, method) do |*args|
          push id, *args
        end
      end

      @tree = new
    end
  end

  # [Detail]
  # Service actor, which can define itself via its dispatch tree.
  class DefinedService < Meta
    include Celluloid::IO

    def initialize(name, endpoints, dispatch)
      @name = name
      @dispatch = dispatch

      @counter = 1
      @sessions = Hash.new

      LOG.debug "Initializing '#{name}' service - with possible endpoints: #{endpoints}"
      endpoints.each do |host, port|
        LOG.debug "Trying to connect to '#{name}' at '[#{host}]:#{port}'"
        begin
          @endpoint = [host, port]
          @socket = TCPSocket.new(host, port)
          break
        rescue IOError => err
          LOG.warn "Failed: #{err}"
        end
      end

      dispatch.each do |id, (method, txtree, rxtree)|
        LOG.debug "Defined '#{method}' method for service #{self}"
        self.metaclass.send(:define_method, method) do |*args|
          LOG.debug "Invoking #{@name}.#{method}(#{args})"
          return invoke(id, *args)
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
      LOG.debug "-> [#{session}, #{id}, #{payload}]"
      tx, rx = @sessions[session]
      if rx
        rx.push id, payload
      else
        LOG.warn "Received message to closed session: [#{session}, #{id}, #{payload}]"
      end
    end

    def invoke(id, *args)
      method, txtree, rxtree = @dispatch[id]
      LOG.debug "Invoking #{@name}[#{id}=#{method}] with #{args}"

      txchan = TxChannel.new txtree, @counter, @socket
      rxchan = RxChannel.new rxtree
      @sessions[@counter] = [txchan, rxchan.tx]

      LOG.debug "<- [#{@counter}, #{id}, #{args}]"
      message = MessagePack.pack([@counter, id, args])
      @counter += 1

      @socket.write message
      return txchan, rxchan.rx
    end
  end

  # [API]
  class Locator < DefinedService
    def initialize(host=nil, port=nil)
      super :locator, [[host || Default::Locator.host, port || Default::Locator.port]], Default::Locator::API
    end
  end

  class ServiceError < IOError
  end

  # [API]
  # Service class. All you need is name and (optionally) locator endpoint.
  class Service < DefinedService
    def initialize(name, host=nil, port=nil)
      locator = Locator.new host, port
      tx, rx = locator.resolve name
      id, payload = rx.recv
      if id == Default::Locator::ERROR_CODE
        raise ServiceError.new payload
      end

      endpoints, version, dispatch = payload
      super name, endpoints, dispatch
    end
  end

  # [Detail]
  # Special worker actor for RAII.
  class WorkerActor
    include Celluloid

    def initialize(block)
      @block = block
    end

    def execute(tx, rx)
      @block.call tx, rx
      yield
    end
  end

  # [API]
  # Worker class.
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
      LOG.debug "Starting worker '#{@app}' with uuid '#{@uuid}' at '#{@endpoint}'"
      @socket = UNIXSocket.open(@endpoint)
      async.handshake
      async.health
      async.serve
    end

    private
    def handshake
      LOG.debug '<- Handshake'
      @socket.write MessagePack::pack([1, RPC::HANDSHAKE, [@uuid]])
    end

    def health
      heartbeat = MessagePack::pack([1, RPC::HEARTBEAT, []])
      loop do
        LOG.debug '<- Heartbeat'
        @socket.write heartbeat
        sleep 5.0
      end
    end

    def serve
      unpacker = MessagePack::Unpacker.new
      loop do
        data = @socket.readpartial 4096
        unpacker.feed_each data do |decoded|
          async.received *decoded
        end
      end
    end

    def received(session, id, payload)
      LOG.debug "-> Message(#{session}, #{id}, #{payload})"
      case id
        when RPC::HANDSHAKE
        when RPC::HEARTBEAT
        when RPC::TERMINATE
          terminate *payload
        when RPC::INVOKE
          invoke session, *payload
        when RPC::CHUNK, RPC::ERROR
          push session, id, *payload
        when RPC::CHOKE
          LOG.debug "Closing #{session} session"
          @sessions.delete session
        else
          LOG.warn "Received unknown message: [#{session}, #{id}, #{payload}]"
      end
    end

    def invoke(session, event)
      actor = @actors[event]
      txchan = TxChannel.new RPC::TXTREE, session, @socket
      rxchan = RxChannel.new RPC::RXTREE

      if actor
        @sessions[session] = [txchan, rxchan.tx]
        actor.execute txchan, rxchan.rx do
          LOG.debug '<- Choke'
          txchan.close
        end
      else
        LOG.warn "Event '#{event}' is not registered"
        txchan.error -1, "event '#{event}' is not registered"
      end
    end

    def push(session, id, *payload)
      tx, rx = @sessions[session]
      if rx
        rx.push id, *payload
      else
        raise Exception.new "received push event on unknown #{session} session"
      end
    end

    def terminate(errno, reason)
      LOG.warn "Terminating [#{errno}]: #{reason}"
      exit errno
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
        opts.banner = 'Usage: <worker.rb> --app NAME --locator ADDRESS --uuid UUID --endpoint ENDPOINT'

        opts.on('--app NAME', 'Worker name') do |app|
          options[:app] = app
        end

        opts.on('--locator ADDRESS', 'Locator address') do |endpoint|
          options[:locator] = endpoint
        end

        opts.on('--uuid UUID', 'Worker uuid') do |uuid|
          options[:uuid] = uuid
        end

        opts.on('--endpoint ENDPOINT', 'Worker endpoint') do |endpoint|
          options[:endpoint] = endpoint
        end
      end.parse!

      Cocaine::LOG.debug "Options: #{options}"
      if options.empty? or options.any? { |option, value| value.nil? }
        Cocaine::LOG.error "Some options aren't specified, but should be. "\
        "Probably, you're trying to start your application manually. Try to restart your app using Cocaine."
        exit 1
      end

      Default::Locator.host, sep, Default::Locator.port = options[:locator].rpartition(':')
      Default::Locator.port = Default::Locator::port.to_i

      Cocaine::LOG.debug "Setting default Locator endpoint to '#{Default::Locator.host}:#{Default::Locator.port}'"
      return Worker.new(options[:app], options[:uuid], options[:endpoint])
    end
  end

  class Rack
    def self.on(event)
      worker = Cocaine::WorkerFactory.create

      worker.on :http do |res, req|
        id, payload = req.recv
        Cocaine::LOG.debug "After receive: '#{{:id => id, :payload => payload}}'"

        case id
          when Cocaine::RPC::CHUNK
            method, url, version, headers, body = MessagePack::unpack payload
            Cocaine::LOG.debug "After unpack: '#{id}, #{[method, url, version, headers, body]}'"

            env = Hash[*headers.flatten]
            parsed_url = URI.parse("http://#{env['Host']}#{url}")
            default_host = parsed_url.hostname  || 'localhost'
            default_port = parsed_url.port      || '80'

            # noinspection RubyStringKeysInHashInspection
            env.update(
                {
                    'GATEWAY_INTERFACE' => 'CGI/1.1',
                    'PATH_INFO'         => parsed_url.path  || '',
                    'QUERY_STRING'      => parsed_url.query || '',
                    'REMOTE_ADDR'       => '::1',
                    'REMOTE_HOST'       => 'localhost',
                    'REQUEST_METHOD'    => method,
                    'REQUEST_URI'       => url,
                    'SCRIPT_NAME'       => '',
                    'SERVER_NAME'       => default_host,
                    'SERVER_PORT'       => default_port.to_s,
                    'SERVER_PROTOCOL'   => "HTTP/#{version}",
                    'rack.version'      => [1, 5],
                    'rack.input'        =>  body,
                    'rack.errors'       => $stderr,
                    'rack.multithread'  => true,
                    'rack.multiprocess' => false,
                    'rack.run_once'     => false,
                    'rack.url_scheme'   => 'http',
                    'HTTP_VERSION'      => "HTTP/#{version}",
                    'REQUEST_PATH'      => parsed_url.path,
                }
            )

            Cocaine::LOG.debug "ENV: #{env}"

            now                        = Time.now
            code, headers, body        = yield env
            headers['X-Response-Took'] = Time.now - now
            res.write MessagePack.pack [code, headers.to_a]
            body.each do |item|
              res.write(item)
            end

            body.close if body.respond_to?(:close)
          when Cocaine::RPC::ERROR
          when Cocaine::RPC::CHOKE
          else
            # Type code here.
        end
      end

      worker.run
      sleep
    end
  end
end
