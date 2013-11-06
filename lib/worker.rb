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
    $log.debug 'starting worker'
    $log.debug "connecting to the #{@endpoint}"
    EM.connect @endpoint, nil, Cocaine::Connection do |conn|
      @dispatcher = Cocaine::WorkerDispatcher.new conn
      @dispatcher.send_handshake 0, @uuid
      @dispatcher.send_heartbeat 0
    end
  end
end