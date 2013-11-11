#!/usr/bin/env ruby

require 'cocaine'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

class Echo
  def execute(request, response)
    df = request.read
    df.callback do |msg|
      $log.debug "Message received: #{msg}"
      response.write msg
      response.close
    end
  end
end

w = Cocaine::WorkerFactory.create
w.on 'ping', Echo.new
w.run()