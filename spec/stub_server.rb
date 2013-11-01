require 'eventmachine'

class StubServer
  module Server
    def callback(&block)
      @callback = block
    end

    def receive_data(data)
      @callback.call data if @callback
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
      server.callback &@callback
      server.response = options[:response]
    end
  end

  def on_receive(&block)
    @callback ||= block
  end

  def stop
    EventMachine.stop_server @sig
  end
end