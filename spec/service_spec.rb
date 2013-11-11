require 'rspec'

require_relative '../lib/cocaine/service'
require_relative '../lib/cocaine/protocol'
require_relative '../lib/cocaine/synchrony/service'

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

  example 'resolving node service' do
    EventMachine.run do
      locator = Cocaine::Locator.new
      connection = locator.resolve('node')
      connection.callback { |endpoint, version, api|
        expect(endpoint[0]).to be_a(String)
        expect(1024 <= endpoint[1] && endpoint[1] <= 65535).to be true
        expect(version).to eq(1)
        expect(api).to eq({0=>'start_app',1 => 'pause_app', 2 => 'list'})
        EventMachine.stop()
      }.errback { |errno, reason|
        fail("[#{errno}] #{reason}")
        EventMachine.stop()
      }
    end
  end
end

describe Cocaine::Service do
  example 'using node service' do
    flag = false
    EventMachine.run do
      service = Cocaine::Service.new 'node'
      d = service.connect
      d.callback {
        service.list.callback {
          flag = true
          EventMachine.stop
        }.errback { |err|
          puts "error: #{err}"
          EventMachine.stop
        }
      }.errback {
        EM.stop
      }
    end
    expect(flag).to be true
  end
end

describe Cocaine::Synchrony::Service do
  example 'synchrony usage of echo service' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping', 'message')
      msg = ch.read
      expect(msg).to eq('message')
      EM.stop
    end
  end

  example 'synchrony usage of streaming echo service' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping-streaming', 'message')
      msg = [nil] * 3
      msg[0] = ch.read
      msg[1] = ch.read
      msg[2] = ch.read
      expect(msg).to eq(['message', 'message!', 'message! :)'])
      EM.stop
    end
  end

  example 'synchrony usage of streaming echo service with collect method' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping-streaming', 'message')
      msg= ch.collect(3)
      expect(msg).to eq(['message', 'message!', 'message! :)'])
      EM.stop
    end
  end
end