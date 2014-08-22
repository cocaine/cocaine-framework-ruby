#!/usr/bin/env ruby

require 'cocaine'

class Echo
  def exec(response, request)
    Cocaine::LOG.debug 'Before read'
    msg = request.read
    Cocaine::LOG.debug "After read: '#{msg}'"
    response.write 4, msg[0]
    Cocaine::LOG.debug 'After write'
  end
end


worker = Cocaine::WorkerFactory.create
worker.on :ping, Echo.new
# worker.on(:ping) do |response, request|
#   Cocaine::LOG.debug 'Before read'
#   msg = request.read
#   Cocaine::LOG.debug "After read: '#{msg}'"
#   response.write 0, msg
#   Cocaine::LOG.debug 'After write'
# end
worker.run
sleep