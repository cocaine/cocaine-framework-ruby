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
    @timers = {
        disown: DisownTimer.new(options[:disown]),
        heartbeat: HeartbeatTimer.new(options[:heartbeat])
    }
  end

  def start
    @timers[:heartbeat].start { exhale }
  end

  def breath
    @timers[:disown].cancel
  end

  :private
  def exhale
    @timers[:disown].start
    @dispatcher.send_heartbeat 0
  end
end