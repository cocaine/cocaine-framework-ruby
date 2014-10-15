#!/usr/bin/env bundle exec

require 'cocaine'

Cocaine::Rack.on :http do |env|
  ['200', {:'Content-Type' => 'text/html'}, ['Hello Rack Participants']]
end
