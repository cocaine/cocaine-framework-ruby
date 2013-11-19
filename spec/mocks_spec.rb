require 'rspec'

require_relative '../lib/cocaine/testing/mock_server'

describe 'mock testing' do
  it 'should pass' do
    EM.synchrony do
      server = CocaineRuntimeMock.new
      server.register 'echo', 1,
                      endpoint: ['localhost', 10054],
                      version: 1,
                      api: {0 => :enqueue, 1 => :info}
      server.on 'echo',
                [0, 1, ['ping', 'message']],
                ['wow', 'another', 'finish']
      server.run

      service = Cocaine::Synchrony::Service.new 'echo'
      ch = service.enqueue 'ping', 'message'
      rs = ch.collect
      puts "#{rs}"
      EM.stop
    end
  end
end