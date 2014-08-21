require 'logger'
require 'msgpack'

require 'celluloid'
require 'celluloid/io'

module Cocaine
  LOG = Logger.new STDERR
  LOG.level = Logger::DEBUG

  class Meta
    def metaclass
      class << self
        self
      end
    end
  end

  module Default
    module Locator
      ENDPOINT = ['localhost', 10053]
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

  class RxChannel < Meta
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
          @client
        end
      end

      @queue << [id, payload]
    end

    def get(timeout=1.0)
      @queue.receive timeout
    end
  end

  class TxChannel < Meta
    def initialize(tree)
      tree.each do |id, (method, txtree, rxtree)|
        LOG.debug "defining '#{method}' method for transmit channel"
        self.metaclass.send(:define_method, method) do |*args|
          return push id, txtree, rxtree, args
        end
      end
    end

    # Called by used (implicitly via dynamically named methods), when he/she wants to send message to the session.
    def push(id, txtree, rxtree, *args)
      # TODO: Complete.
      # Traverse the tree.
      # If new state - delete old methods for service.
      # Create message.
      # Push message.
    end
  end

  class DefinedService < Meta
    include Celluloid::IO

    DNS = Resolv::DNS.new

    def initialize(name, endpoint, dispatch)
      @name = name
      @endpoint = endpoint
      @dispatch = dispatch

      @counter = 1
      @sessions = Hash.new

      host, port = endpoint
      LOG.debug "Initializing '#{name}' service at #{host}:#{port}"
      dispatch.each do |id, (method, txtree, rxtree)|
        self.metaclass.send(:define_method, method) do |*args|
          LOG.debug "Invoking #{@name}.#{method}(#{args})"
          return invoke(id, *args)
        end
      end

      LOG.debug "Resolving host '#{host}'"
      DNS.getaddresses(host).each do |address|
        LOG.debug "Connecting to the '#{name}' service at #{address}:#{port}"
        @socket = TCPSocket.new(address, port)
      end

      async.run
    end

    def run
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
      tx, rx = @sessions[@counter] = [TxChannel.new(txtree), (RxChannel.new rxtree)]

      LOG.debug "-> [#{@counter}, #{id}, #{args}]"
      message = MessagePack.pack([@counter, id, [*args]])
      @counter += 1

      @socket.write message
      return tx, rx
    end
  end

  class Locator < DefinedService
    def initialize
      super :locator, Default::Locator::ENDPOINT, Default::Locator::API
    end
  end

  class Service < DefinedService
    def initialize(name)
      locator = Locator.new
      tx, rx = locator.resolve name
      id, (endpoint, version, dispatch) = rx.get
      super name, endpoint, dispatch
    end
  end

  class Worker
  end
end