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

  def start(&block)
    @timer = EM::Timer.new @timeout do
      block.call
    end
  end
end


class HeartbeatTimer < Timer
  def initialize(timeout = 30.0)
    super timeout
  end

  def start(&block)
    @timer = EM::PeriodicTimer.new @timeout do
      block.call
    end
  end
end


class Cocaine::HealthManager
  def initialize(dispatcher, options={})
    @dispatcher = dispatcher
    options = {disown: 10.0, heartbeat: 30.0}.merge options
    @disown = DisownTimer.new(options[:disown])
    @heartbeat = HeartbeatTimer.new(options[:heartbeat])
  end

  def start
    $log.debug 'health manager has been started'
    @heartbeat.start { exhale }
  end

  def breath
    $log.debug '[->] doing breath'
    @disown.cancel
  end

  :private
  def exhale
    $log.debug '[<-] doing exhale'
    @disown.start {
      $log.error 'disowned'
      EM.next_tick { EM.stop }
    }
    @dispatcher.send_heartbeat 0
  end
end