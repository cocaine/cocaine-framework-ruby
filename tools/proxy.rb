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

  id, payload = rx.recv
  case id
    when :write
      code, headers = MessagePack::unpack payload[0]
      Cocaine::LOG.debug "#{id}, #{code} :: #{headers}"
      id, body = rx.recv
      body = body[0]

      Cocaine::LOG.debug :headers => headers
      Cocaine::LOG.debug :body    => body
      headers.each do |key, value|
        res[key] = value
      end

      res.body = body
    when :error
      errno, reason = payload
      res.body = reason
    when :choke
      res.body = 'EOF'
    else
      res.body = 'Error'
  end
end
server.start