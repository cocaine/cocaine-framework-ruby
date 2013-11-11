require 'rubygems'
require 'logger'

require 'msgpack'
require 'eventmachine'

require 'cocaine/channel'
require 'cocaine/connection'
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
  def initialize(name)
    @name = name
  end

  :private
  def connect_to_endpoint(*endpoint)
    df = EM::DefaultDeferrable.new
    EM.connect *endpoint, Cocaine::Connection do |conn|
      $log.debug "connection established with service '#{@name}' at #{endpoint}"
      @dispatcher = Cocaine::ClientDispatcher.new conn
      if conn.error?
        df.fail conn.error?
      else
        df.succeed
      end
    end
    df
  end

  def invoke(method_id, *args)
    $log.debug "invoking '#{@name}' method #{method_id} with #{args}"
    @dispatcher.invoke method_id, *args
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

  :private
  def do_resolve(name, df)
    $log.debug "resolving service '#{name}'"
    channel = invoke 0, name
    channel.callback { |result| df.succeed result }
    channel.errback { |err| df.fail err }
  end
end


class Cocaine::Service < Cocaine::AbstractService
  def connect
    df = EventMachine::DefaultDeferrable.new
    locator = Cocaine::Locator.new
    d = locator.resolve @name
    d.callback { |result| on_connect result, df }
    df
  end

  :private
  def on_connect(result, df)
    $log.debug "service '#{@name}' resolved: #{result}"

    endpoint, version, api = result
    $log.debug "protocol version: #{version}"

    api.each do |id, name|
      self.metaclass.send(:define_method, name) do |*args|
        invoke id, *args
      end
    end

    connect_df = connect_to_endpoint *endpoint
    connect_df.callback { df.succeed }
    connect_df.errback { |err| df.fail err }
  end
end