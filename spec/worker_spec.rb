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
        EM.stop
      }
      worker = Cocaine::Worker.new endpoint: '/tmp/cocaine.sock'
      worker.run
    end
  end

  #it 'should send handshake after connecting to the socket' do
end