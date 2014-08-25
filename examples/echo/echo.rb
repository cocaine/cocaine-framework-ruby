#!/usr/bin/env ruby

require 'cocaine'

worker = Cocaine::WorkerFactory.create

worker.on :ping do |response, request|
  Cocaine::LOG.debug 'Before read'
  id, msg = request.receive
  Cocaine::LOG.debug "After read: '#{id}, #{msg}'"
  response.write msg
  Cocaine::LOG.debug 'After write'
end

worker.run
sleep