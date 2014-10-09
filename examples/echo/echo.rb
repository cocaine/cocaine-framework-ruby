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
    when Cocaine::RPC::ERROR
      Cocaine::LOG.debug 'Error event'
    when Cocaine::RPC::CHOKE
      Cocaine::LOG.debug 'Choke event'
    else
      Cocaine::LOG.debug 'Unknown event'
  end

  Cocaine::LOG.debug 'After write'
end

worker.run
sleep