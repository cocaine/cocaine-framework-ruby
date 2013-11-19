require 'rspec'
require_relative '../lib/cocaine/synchrony/service'

#describe Cocaine::Synchrony::Service do
#  example 'synchrony usage of echo service' do
#    EM.synchrony do
#      service = Cocaine::Synchrony::Service.new 'echo-ruby'
#      ch = service.enqueue('ping', 'message')
#      msg = ch.read
#      expect(msg).to eq('message')
#      EM.stop
#    end
#  end
#
#  example 'synchrony usage of streaming echo service' do
#    EM.synchrony do
#      service = Cocaine::Synchrony::Service.new 'echo-ruby'
#      ch = service.enqueue('ping-streaming', 'message')
#      msg = [nil] * 3
#      msg[0] = ch.read
#      msg[1] = ch.read
#      msg[2] = ch.read
#      expect(msg).to eq(['message', 'message!', 'message! :)'])
#      EM.stop
#    end
#  end
#
#  example 'synchrony usage of streaming echo service with partial collect method' do
#    EM.synchrony do
#      service = Cocaine::Synchrony::Service.new 'echo-ruby'
#      ch = service.enqueue('ping-streaming', 'message')
#      msg= ch.collect(2)
#      expect(msg).to eq(['message', 'message!'])
#      EM.stop
#    end
#  end
#
#  example 'synchrony usage of streaming echo service with full collect method' do
#    EM.synchrony do
#      service = Cocaine::Synchrony::Service.new 'echo-ruby'
#      ch = service.enqueue('ping-streaming', 'message')
#      msg= ch.collect(3)
#      expect(msg).to eq(['message', 'message!', 'message! :)'])
#      EM.stop
#    end
#  end
#
#  example 'synchrony usage of streaming echo service with collect until choke method' do
#    EM.synchrony do
#      service = Cocaine::Synchrony::Service.new 'echo-ruby'
#      ch = service.enqueue('ping-streaming', 'message')
#      msg= ch.collect()
#      expect(msg).to eq(['message', 'message!', 'message! :)'])
#      EM.stop
#    end
#  end
#
#  example 'synchrony usage of streaming echo service with each' do
#    EM.synchrony do
#      service = Cocaine::Synchrony::Service.new 'echo-ruby'
#      ch = service.enqueue('ping-streaming', 'message')
#      results = []
#      ch.each do |result|
#        results.push result
#      end
#      expect(results).to eq(['message', 'message!', 'message! :)'])
#      EM.stop
#    end
#  end
#
#  example 'synchrony usage of service with wrong event name' do
#    EM.synchrony do
#      service = Cocaine::Synchrony::Service.new 'echo-ruby'
#      ch = service.enqueue('ping-wrong', 'message')
#      expect { ch.read }.to raise_error(Cocaine::ServiceError)
#      EM.stop
#    end
#  end
#
#  example 'synchrony throws exception when service is not available' do
#    EM.synchrony do
#      expect { Cocaine::Synchrony::Service.new 'non-existing-app' }.to raise_error(Cocaine::ServiceError)
#      EM.stop
#    end
#  end
#end