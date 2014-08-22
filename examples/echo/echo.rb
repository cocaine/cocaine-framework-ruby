#!/usr/bin/env ruby

require 'cocaine'

worker = Cocaine::WorkerFactory.create

worker.on :ping do |response, request|
  Cocaine::LOG.debug 'Before read'
  msg = request.read
  Cocaine::LOG.debug "After read: '#{msg}'"
  response.write msg[0]
  Cocaine::LOG.debug 'After write'
end

worker.run
sleep