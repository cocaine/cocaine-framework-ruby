require 'connection'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG


class Cocaine::Worker
  def initialize(options={})
    options = {endpoint: '', uuid: ''}.merge(options)

    @endpoint = options[:endpoint]
    @uuid = options[:uuid]
  end

  def on
  end

  def run
    EM.run do
      $log.debug 'starting worker'
      $log.debug "connecting to the #{@endpoint}"
      EM.connect @endpoint, nil, Cocaine::Connection do |conn|
        @dispatcher = Cocaine::WorkerDispatcher.new self, conn
        @dispatcher.send_handshake 0, @uuid
        @dispatcher.send_heartbeat 0
      end
    end
  end

  def terminate(errno, reason)
    $log.debug "terminating with [#{errno}] #{reason}"
    @dispatcher.send_terminate 0, errno, reason
  end
end