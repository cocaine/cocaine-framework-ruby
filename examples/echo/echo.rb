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
  include Cocaine::Http

  def execute(request, response)
    df = request.read
    df.callback { |req|
      msg = req.query['message']
      response.add_header('Content-Type', 'plain/text')
      response.write_body(msg)
      response.close
    }
  end
end

w = Cocaine::WorkerFactory.create
w.on 'ping', Echo.new
w.on 'ping-streaming', EchoStreaming.new
w.on 'ping-http', HttpEcho.new
w.run()