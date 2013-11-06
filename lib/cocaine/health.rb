class Cocaine::HealthManager
  def initialize(dispatcher)
    @dispatcher = dispatcher
    @dispatcher.send_handshake 0
    @dispatcher.send_heartbeat 0
  end
end