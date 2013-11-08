#!/usr/bin/env ruby

require 'cocaine'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

class Echo
  def execute
    puts 'Hi!'
  end
end

w = Cocaine::WorkerFactory.create
w.on 'ping', Echo.new
w.run()