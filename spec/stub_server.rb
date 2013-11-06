require 'eventmachine'

class StubServer
  module Server
    def callback(&block)
      @callback = block
    end

    def on=(on)
      @on = on
    end

    def receive_data(data)
      @callback.call data if @callback
      if @on && @on.has_key?(data)
        @on[data].call self
      end
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
      if @on_connect
        @on_connect.call
      end
      server.callback &@callback
      server.on = @on
      server.response = options[:response]
    end
  end

  def on_connect(&block)
    @on_connect ||= block
  end

  def on_receive(&block)
    @callback ||= block
  end

  def on(msg, &block)
    @on ||= {}
    @on[msg] = block
  end

  def stop
    EventMachine.stop_server @sig
  end
end