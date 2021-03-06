#!/usr/bin/env ruby

require 'cocaine'

worker = Cocaine::WorkerFactory.create

worker.on :ping do |res, req|
  Cocaine::LOG.debug 'Before read'
  id, msg = req.recv
  Cocaine::LOG.debug "After read: '#{id}, #{msg}'"

  case id
  when :write
      res.write msg
    when :error
      Cocaine::LOG.debug 'Error event'
    else
      Cocaine::LOG.debug 'Unknown event'
  end

  Cocaine::LOG.debug 'After write'
end

worker.run
sleep