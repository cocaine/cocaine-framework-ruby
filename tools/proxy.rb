#!/usr/bin/env ruby

require 'cocaine'
require 'webrick'

service = Cocaine::Service.new 'rails'
server = WEBrick::HTTPServer.new :Port => 8000

trap 'INT' do
  server.shutdown
end

server.mount_proc '/' do |req, res|
  payload = [req.request_method, req.unparsed_uri, 1.1, req.header.to_a, req.body || '']
  Cocaine::LOG.debug payload

  tx, rx = service.enqueue :http
  tx.write MessagePack::pack payload

  id, payload = rx.receive
  case id
    when 0
      code, headers = MessagePack::unpack payload[0]
      Cocaine::LOG.debug "#{id}, #{code} :: #{headers}"
      id, body = rx.receive
      body = body[0]

      Cocaine::LOG.debug :headers => headers
      Cocaine::LOG.debug :body    => body
      headers.each do |key, value|
        res[key] = value
      end

      res.body = body
    when 1
      errno, reason = payload
      res.body = reason
    when 2
      res.body = 'EOF'
    else
      res.body = 'Error'
  end
end
server.start