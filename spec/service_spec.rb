require 'rspec'

require_relative '../lib/cocaine/client/service'
require_relative '../lib/cocaine/protocol'
require_relative '../lib/cocaine/synchrony/service'
require_relative '../lib/cocaine/testing/mock_server'

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

  it 'should send correct message to the locator while resolving service' do
    EM.run do
      expected = {endpoint: ['127.0.0.1', 10054], version: 1, api: {0 => 'start_app', 1 => 'pause_app', 2 => 'list'}}
      server = CocaineRuntimeMock.new
      server.register 'node', 1, expected
      server.run

      locator = Cocaine::Locator.new
      locator.resolve('node').callback { |endpoint, version, api|
        expect(endpoint).to eq(expected[:endpoint])
        expect(version).to eq(expected[:version])
        expect(api).to eq(expected[:api])
        EM.stop()
      }.errback {
        fail('Failed')
        EM.stop()
      }
    end
  end
end

describe Cocaine::Service do
  it 'should connect to the provided endpoint' do
    flag = false
    EM.run do
      expected = {endpoint: ['127.0.0.1', 10054], version: 1, api: {0 => 'start_app', 1 => 'pause_app', 2 => 'list'}}
      server = CocaineRuntimeMock.new
      server.register 'node', 1, expected
      server.when('node').connected do
        flag = true
        EM.stop
      end
      server.run

      node = Cocaine::Service.new 'node'
      node.connect
    end
    expect(flag).to be true
  end

  it 'should provide methods dynamically' do
    flag = false
    EM.run do
      expected = {endpoint: ['127.0.0.1', 10054], version: 1, api: {0 => 'start_app', 1 => 'pause_app', 2 => 'list'}}
      server = CocaineRuntimeMock.new
      server.register 'node', 1, expected
      #server.on 'node', [2, 1, []], []
      server.when('node').message([2, 1, []]) do
        flag = true
        EM.stop
        ['app']
      end
      server.run

      node = Cocaine::Service.new 'node'
      node.connect.callback {
        node.list
      }.errback { |err|
        fail("Failed: #{err}")
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

  example 'synchrony usage of streaming echo service with partial collect method' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping-streaming', 'message')
      msg= ch.collect(2)
      expect(msg).to eq(['message', 'message!'])
      EM.stop
    end
  end

  example 'synchrony usage of streaming echo service with full collect method' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping-streaming', 'message')
      msg= ch.collect(3)
      expect(msg).to eq(['message', 'message!', 'message! :)'])
      EM.stop
    end
  end

  example 'synchrony usage of streaming echo service with collect until choke method' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping-streaming', 'message')
      msg= ch.collect()
      expect(msg).to eq(['message', 'message!', 'message! :)'])
      EM.stop
    end
  end

  example 'synchrony usage of streaming echo service with each' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping-streaming', 'message')
      results = []
      ch.each do |result|
        results.push result
      end
      expect(results).to eq(['message', 'message!', 'message! :)'])
      EM.stop
    end
  end

  example 'synchrony usage of service with wrong event name' do
    EM.synchrony do
      service = Cocaine::Synchrony::Service.new 'echo-ruby'
      ch = service.enqueue('ping-wrong', 'message')
      expect { ch.read }.to raise_error(Cocaine::ServiceError)
      EM.stop
    end
  end

  example 'synchrony throws exception when service is not available' do
    EM.synchrony do
      expect { Cocaine::Synchrony::Service.new 'non-existing-app' }.to raise_error(Cocaine::ServiceError)
      EM.stop
    end
  end
end
