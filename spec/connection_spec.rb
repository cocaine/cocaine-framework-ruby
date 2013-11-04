require 'rspec'
require 'msgpack'

require_relative '../lib/connection'
require_relative '../lib/protocol'

require_relative 'stub_server'

describe Cocaine::Connection do
  it 'should transmit received data to decoder' do
    EventMachine::run {
      msg = [4, 1, [['0.0.0.0', 0], 0, {0 => 'method'}].to_msgpack]
      encoded_msg = msg.to_msgpack
      server = StubServer.new(response: encoded_msg)

      decoder = double()
      expect(decoder).to receive(:feed).with(encoded_msg) do |&arg|
        arg.call(msg)
      end
      EventMachine.connect '127.0.0.1', 9053, Cocaine::Connection, decoder do |conn|
        dispatcher = Cocaine::ClientDispatcher.new conn
        channel = dispatcher.invoke 0, 'bullshit'
        channel.callback {
          server.stop
          EventMachine::stop
        }
      end
    }
  end
end