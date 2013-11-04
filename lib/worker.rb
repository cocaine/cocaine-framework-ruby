require 'connection'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG


class Cocaine::Worker
  def initialize(options={})
    options = {endpoint: ''}.merge(options)

    @endpoint = options[:endpoint]
  end

  def run
    $log.debug 'starting worker'
    $log.debug "connecting to the #{@endpoint}"
    EM.connect @endpoint, nil, Cocaine::Connection do |conn|
      @dispatcher = Cocaine::WorkerDispatcher.new conn
      # Activate health manager
      ## Send handshake

      @dispatcher.send_heartbeat 0
      ## Send heartbeat
    end
  end
end