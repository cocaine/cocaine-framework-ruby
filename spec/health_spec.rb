require 'rspec'

require_relative '../lib/cocaine/health'

describe Cocaine::HealthManager do

  it 'should send handshake and heartbeat on initialization' do
    d = double()
    d.should_receive(:send_handshake).with(0)
    d.should_receive(:send_heartbeat).with(0)
    Cocaine::HealthManager.new d
  end
end