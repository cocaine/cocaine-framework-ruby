require 'rspec'

require_relative '../lib/service'
require_relative '../lib/protocol'

require_relative 'stub_server'

describe Cocaine::Locator do

  it 'should send correct message to the server' do
    EM.run do
      response = [RPC::CHUNK, 1, [[], 1, {}].to_msgpack].to_msgpack
      stub = StubServer.new(host: 'localhost', port: 20053, response: response)
      stub.on_receive { |actual| actual.equal? [0, 1, %w(node)].to_msgpack }

      locator = Cocaine::Locator.new 'localhost', 20053
      df = locator.resolve 'node'
      df.callback {
        EM.stop
      }.errback {
        fail
      }
    end
  end
end