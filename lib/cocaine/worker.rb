require 'optparse'

require 'cocaine/connection'
require 'cocaine/sandbox'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::Worker
  def initialize(options={})
    options = {
        endpoint: '',
        uuid: '',
    }.merge(options)

    @endpoint = options[:endpoint]
    @uuid = options[:uuid]

    @sandbox = Cocaine::Sandbox.new
  end

  def on(event, handler)
    @sandbox.on event, handler
  end

  def run
    EM.error_handler { |error|
      short_reason = error.inspect
      traceback = error.backtrace.join("\n")
      $log.warn "error caught at the top of event loop:\n#{short_reason}\n#{traceback}"
    }

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

  def invoke(event, request, response)
    @sandbox.invoke(event, request, response)
  end

  def terminate(errno, reason)
    $log.debug "terminating with: [#{errno}] #{reason}"
    @dispatcher.send_terminate 0, errno, reason
    EM.stop
    exit(errno)
  end
end


class Cocaine::WorkerFactory
  def self.create
    options = {}
    OptionParser.new do |opts|
      opts.banner = 'Usage: <your_worker.rb> --app NAME --locator ADDRESS --uuid UUID --endpoint ENDPOINT'

      opts.on('--app NAME', 'Worker name') { |a| options[:app] = a }
      opts.on('--locator ADDRESS', 'Locator address') { |a| options[:locator] = a }
      opts.on('--uuid UUID', 'Worker uuid') { |a| options[:uuid] = a }
      opts.on('--endpoint ENDPOINT', 'Worker endpoint') { |a| options[:endpoint] = a }
    end.parse!
    return Cocaine::Worker.new options
  end
end