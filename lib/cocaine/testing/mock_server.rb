require 'em-synchrony'
require 'logger'

require 'cocaine/synchrony/service'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

class CocaineRuntimeMock
  module Server
    def initialize(name='locator', options={})
      $log.debug "new connection for '#{name}'"
      @name = name
      @options = options
      @responses = {}
    end

    def post_init
      $log.debug 'connection accepted'
    end

    def receive_data(data)
      up ||= MessagePack::Unpacker.new
      up.feed_each data do |chunk|
        $log.debug "received data: #{chunk}"
        return unless @responses.has_key? chunk

        id, session, data = chunk

        response = @responses[chunk]
        $log.debug "iterating over response: #{response}"
        response.each do |ch|
          if ch.is_a? Error
            send_data ch.pack session
          else
            send_data (Chunk.new ch.to_msgpack).pack session
          end
        end
        send_data Choke.new.pack session
      end
    end

    def on(handlers)
      @responses = handlers
    end
  end

  def initialize(options = {})
    options = {:host => 'localhost', :port => 10053}.merge(options)

    @host = options[:host]
    @port = options[:port]
    @services = {}
    @responses = {}

    @servers = []

    register 'locator', 0, endpoint: [@host, @port], version: 1, api: {}
  end

  def register(name, session, options={})
    raise "service '#{name}' already registered" if @services.has_key? name

    $log.debug "registering '#{name}' service"

    options = {endpoint: ['localhost', 0], version: 1, api: {}}.merge options
    @services[name] = options

    on 'locator',
       [0, session, [name]],
       [[options[:endpoint], options[:version], options[:api]]]
  end

  def on(name, request, response)
    @responses[name] ||= {}
    @responses[name][request] = response
  end

  def run
    @services.each do |name, options|
      $log.debug "starting '#{name}' service at #{options[:endpoint]}"
      sig = EM::start_server *options[:endpoint], Server, name, options do |server|
        server.on @responses[name]
      end

      @servers.push sig
    end
  end

  def stop
    @servers.each do |sig|
      EM.stop_server sig
    end
  end
end