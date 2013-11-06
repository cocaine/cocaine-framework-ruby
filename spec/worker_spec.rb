require 'rspec'

require_relative '../lib/worker'

require 'stub_server'

describe Cocaine::Worker do
  it 'should be' do
    Cocaine::Worker.new
  end
end

describe Cocaine::Worker, '#protocol' do
  it 'should connect to the endpoint specified' do
    EM.run do
      stub = StubServer.new host: '/tmp/cocaine.sock', port: nil
      stub.on_connect {
        stub.stop
        EM.stop
      }
      worker = Cocaine::Worker.new endpoint: '/tmp/cocaine.sock'
      worker.run
    end
  end

  it 'should send handshake + heartbeat after connecting to the socket' do
    EM.run do
      stub = StubServer.new host: '/tmp/cocaine.sock', port: nil
      stub.on_receive { |msg|
        expect(msg).to eq([0, 0, [''].to_msgpack].to_msgpack + [1, 0, [].to_msgpack].to_msgpack)
        stub.stop
        EM.stop
      }
      worker = Cocaine::Worker.new endpoint: '/tmp/cocaine.sock'
      worker.run
    end
  end
end