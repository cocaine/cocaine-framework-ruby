require 'rspec'

require_relative '../lib/cocaine/health'

describe Cocaine::HealthManager do
  it 'should be' do
    d = double()
    Cocaine::HealthManager.new d
  end

  it 'should send handshake and heartbeat on initialization' do
    d = double()
    d.should_receive(:send_handshake).with(0)
    d.should_receive(:send_heartbeat).with(0)
    health = Cocaine::HealthManager.new d

    EM.run do
      health.start()
      EM.next_tick { EM.stop }
    end
  end

  it 'should stop event loop if nobody takes breath to it until timeout' do
    d = double()
    d.should_receive(:send_handshake).with(0)
    d.should_receive(:send_heartbeat).with(0)
    EM.run do
      health = Cocaine::HealthManager.new d, {disown: 0.0, heartbeat: 0.0}
      health.start()
    end
  end
end