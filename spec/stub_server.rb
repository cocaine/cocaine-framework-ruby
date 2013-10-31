require 'eventmachine'

class StubServer
  module Server
    def receive_data(data)
      send_data @response
      close_connection_after_writing
    end

    def response=(response)
      @response = response
    end
  end

  def initialize(options = {})
    options = {:response => options} if options.kind_of?(String)
    options = {:host => '127.0.0.1', :port => 9053}.merge(options)

    host = options[:host]
    port = options[:port]
    @sig = EventMachine::start_server(host, port, Server) do |server|
      server.response = options[:response]
    end
  end

  def stop
    EventMachine.stop_server @sig
  end
end