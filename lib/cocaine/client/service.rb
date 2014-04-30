require 'rubygems'
require 'logger'

require 'msgpack'
require 'eventmachine'

require 'cocaine/asio/channel'
require 'cocaine/asio/connection'
require 'cocaine/client/dispatcher'
require 'cocaine/client/error'
require 'cocaine/protocol'


class Object
  def metaclass
    class << self
      self
    end
  end
end


$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::AbstractService
  attr_reader :api

  def initialize(name)
    @name = name
    @api = {}
  end

  def invoke(method_id, *args)
    $log.debug "invoking '#{@name}' method #{method_id} with #{args}"
    @dispatcher.invoke method_id, *args
  end

  private
  def connect_to_endpoint(*endpoint)
    df = EM::DefaultDeferrable.new
    $log.debug "connecting to the service '#{@name}' at #{endpoint} ..."
    EM.connect *endpoint, Cocaine::Connection do |conn|
      conn.hooks.on :connected do
        conn.hooks.clear
        $log.debug "connection established with service '#{@name}' at #{endpoint}"
        @dispatcher = Cocaine::ClientDispatcher.new conn
        df.succeed
      end

      conn.hooks.on :disconnected do
        conn.hooks.clear
        $log.debug "failed to connect to the '#{@name}' service at #{endpoint}"
        df.fail Cocaine::ConnectionError.new
      end
    end
    df
  end
end


class Cocaine::Locator < Cocaine::AbstractService
  def initialize(host='localhost', port=10053)
    @name = 'locator'
    @host = host
    @port = port
  end

  def resolve(name)
    df = EventMachine::DefaultDeferrable.new
    connect_df = connect_to_endpoint @host, @port
    connect_df.callback { do_resolve name, df }
    connect_df.errback { |err| df.fail err }
    df
  end

  private
  def do_resolve(name, df)
    $log.debug "resolving service '#{name}'"
    channel = invoke 0, name
    channel.callback do |future|
      begin
        df.succeed future.get
      rescue Exception => err
        df.fail err
      end
    end
  end
end


class Cocaine::Service < Cocaine::AbstractService
  def initialize(name, host='localhost', port=10053)
    super name
  end

  def connect
    df = EventMachine::DefaultDeferrable.new
    locator = Cocaine::Locator.new
    d = locator.resolve @name
    d.callback { |result| on_connect result, df }
    d.errback { |err| df.fail err }
    df
  end

  private
  def on_connect(result, df)
    $log.debug "service '#{@name}' resolved: #{result}"

    @endpoint, @version, @api = result
    @api.each do |id, name|
      self.metaclass.send(:define_method, name) do |*args|
        invoke id, *args
      end
    end

    #todo: No ipv6 support yet
    connect_df = connect_to_endpoint *@endpoint
    connect_df.callback { df.succeed }
    connect_df.errback { |err| df.fail err }
  end
end