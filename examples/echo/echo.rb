#!/usr/bin/env ruby

require 'cocaine'
require 'cocaine/server/http'

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


class EchoStreaming
  def execute(request, response)
    df = request.read
    df.callback do |msg|
      $log.debug "Message received: #{msg}. Sending it back more happily."
      response.write msg
      response.write msg + '!'
      response.write msg + '! :)'
      response.close
    end
  end
end


class HttpEcho
  extend Cocaine::Http

  def execute(request, response)
    df = request.read
    df.callback { |rq|
      msg = rq.query['message']
      $log.debug "Message: #{rq.query}"
      $log.debug "Message: #{msg}"
      response.write_headers(200, ['Content-Type', 'plain/text'])
      response.body = msg
      response.close
    }
  end
  http :execute
end

w = Cocaine::WorkerFactory.create
w.on 'ping', Echo.new
w.on 'ping-streaming', EchoStreaming.new
w.on 'ping-http', HttpEcho.new
w.run()