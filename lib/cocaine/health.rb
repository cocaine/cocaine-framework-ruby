$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG


class Timer
  def initialize(timeout)
    @timeout = timeout
  end
end


class DisownTimer < Timer
  def initialize(timeout = 10.0)
    super timeout
  end

  def start
    @timer = EM::Timer.new @timeout do
      $log.error 'disowned'
      EM.stop
    end
  end
end


class HeartbeatTimer < Timer
  def initialize(timeout = 30.0)
    super timeout
  end
end


class Cocaine::HealthManager
  attr_accessor :timeouts

  def initialize(dispatcher, options={})
    options = {disown: 10.0, heartbeat: 30.0}.merge options
    @dispatcher = dispatcher
    @timers = {
        disown: DisownTimer.new(options[:disown]),
        heartbeat: HeartbeatTimer.new(options[:heartbeat])
    }
  end

  def start
    @dispatcher.send_handshake 0
    @dispatcher.send_heartbeat 0
    @timers[:disown].start
  end

  def breath
    # stop timer
  end
end