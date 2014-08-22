require 'eventmachine'
require 'logger'
require 'msgpack'
require 'optparse'

$log = Logger.new STDERR
$log.level = Logger::DEBUG

class Session
  def initialize(conn, session, info)
    @conn = conn
    @counter = session
    @info = info
  end

  def on(data)
    state = @info[:states][@info[:state]]
    $log.debug "STATE #{state}"

    actions = state[data]
    if actions.nil?
      $log.warn "unknown message: #{data}"
      fallback = state[:*]
      unless fallback.nil?
        process fallback
      end
    else
      actions.each do |action|
        process action
      end
    end
  end

  def process(action)
    id, data = action
    case id
      when :send
        $log.debug "sending #{data}"
        data.unshift(@counter)
        @conn.send_data data.to_msgpack
      when :move
        $log.debug "moving to #{data}"
        @info[:state] = data
      when :drop
        $log.debug "dropping connection: #{@conn}"
        @conn.close
      else
        $log.warn "unknown action: #{id}"
        @conn.close
    end
  end
end

module Server
  attr_accessor :name
  attr_writer :info

  def initialize
    @sessions = Hash.new
  end

  def post_init
    $log.debug 'Received a new connection'
    @unpacker ||= MessagePack::Unpacker.new
  end

  def receive_data(data)
    @unpacker.feed_each(data) do |decoded|
      $log.debug "data: #{decoded}"
      if decoded.kind_of? Array
        session = decoded.shift
        @sessions[session] ||= Session.new self, session, @info
        @sessions[session].on(decoded)
      else
        close
      end
    end
  end

  def close
    close_connection_after_writing
  end
end

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: cocaine-runtime.rb -c CONFIG [--host HOST]'

    opts.on('-c', '--config CONFIG', 'Configuration file') do |config|
      options[:config] = config
    end
  end.parse! ARGV

  autoload(:Config, options[:config])
  config = Config.new

  host = 'localhost'
  EventMachine.run do
    config.services.each do |service, info|
      $log.debug "starting '#{service}' at #{host}:#{info[:port]}"
      info[:sig] = EventMachine::start_server(host, info[:port], Server) do |server|
        server.name = service
        server.info = info
      end
    end
  end
end

main