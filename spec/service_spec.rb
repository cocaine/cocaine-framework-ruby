require 'rspec'

require_relative '../lib/cocaine/client/service'
require_relative '../lib/cocaine/protocol'
require_relative '../lib/cocaine/synchrony/service'
require_relative '../lib/cocaine/testing/mock_server'

require_relative 'stub_server'


describe Cocaine::Locator do
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
  it 'should synchrony connect to the service' do
    flag = false
    EM.synchrony do
      expected = {endpoint: ['127.0.0.1', 10054], version: 1, api: {}}
      server = CocaineRuntimeMock.new
      server.register 'mock-app', 1, expected
      server.when('mock-app').connected do
        flag = true
        EM.stop
      end
      server.run

      Cocaine::Synchrony::Service.new 'mock-app'
    end
    expect(flag).to be true
  end

  it 'should synchrony read exactly one chunk' do
    EM.synchrony do
      expected = {endpoint: ['127.0.0.1', 10054], version: 1, api: {0 => 'enqueue', 1 => 'info'}}
      server = CocaineRuntimeMock.new
      server.register 'mock-app', 1, expected
      server.when('mock-app').message([0, 1, ['ping', 'message']]) { ['chunk#1'] }
      server.run

      service = Cocaine::Synchrony::Service.new 'mock-app'
      ch = service.enqueue('ping', 'message')
      msg = ch.read
      expect(msg).to eq('chunk#1')
      EM.stop
    end
  end

  it 'should synchrony read exactly three chunks' do
    EM.synchrony do
      expected = {endpoint: ['127.0.0.1', 10054], version: 1, api: {0 => 'enqueue', 1 => 'info'}}
      server = CocaineRuntimeMock.new
      server.register 'mock-app', 1, expected
      server.when('mock-app').message([0, 1, ['ping', 'message']]) { ['chunk#1', 'chunk#2', 'chunk#3'] }
      server.run

      service = Cocaine::Synchrony::Service.new 'mock-app'
      ch = service.enqueue('ping', 'message')
      msg = [nil] * 3
      msg[0] = ch.read
      msg[1] = ch.read
      msg[2] = ch.read
      expect(msg).to eq(['chunk#1', 'chunk#2', 'chunk#3'])
      EM.stop
    end
  end
end
