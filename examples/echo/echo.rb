#!/usr/bin/env ruby

require 'cocaine'

worker = Cocaine::WorkerFactory.create

worker.on :ping do |response, request|
  Cocaine::LOG.debug 'Before read'
  id, msg = request.receive
  case id
    when Cocaine::RPC::CHUNK
      Cocaine::LOG.debug "After read: '#{id}, #{msg}'"
      response.write msg
      Cocaine::LOG.debug 'After write'
    when Cocaine::RPC::ERROR
    when Cocaine::RPC::CHOKE
    else
      # Type code here.
  end
end

worker.run
sleep