require 'rubygems'
require 'logger'

require 'msgpack'
require 'eventmachine'

require_relative 'connection'
require_relative 'channel'
require_relative 'protocol'


$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG


class Cocaine::Locator
  def initialize(host='localhost', port=10053)
    @host = host
    @port = port
  end

  def resolve(name)
    deferred = EventMachine::DefaultDeferrable.new
    decoder = Cocaine::Decoder.new
    EventMachine.connect @host, @port, Cocaine::Connection, decoder do |conn|
      $log.debug "resolving service '#{name}'"
      channel = conn.invoke 0, name
      channel.callback { |result| deferred.succeed result }
      channel.errback { |err| deferred.fail err }
    end
    deferred
  end
end