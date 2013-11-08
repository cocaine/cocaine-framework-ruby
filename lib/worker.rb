require 'connection'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::Worker
  def initialize(options={})
    options = {endpoint: '', uuid: ''}.merge(options)

    @endpoint = options[:endpoint]
    @uuid = options[:uuid]
  end

  def on(event, handler)
    puts "!#{event}, #{handler}!"
  end

  def run
    EM.run do
      $log.debug 'starting worker'
      $log.debug "connecting to the #{@endpoint}"
      EM.connect @endpoint, nil, Cocaine::Connection do |conn|
        $log.debug "connection established with #{@endpoint}"
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


class Cocaine::WorkerFactory
  def self.create
    uuid = ARGV[ARGV.index('--uuid') + 1]
    endpoint = ARGV[ARGV.index('--endpoint') + 1]
    return Cocaine::Worker.new uuid: uuid, endpoint: endpoint
  end
end