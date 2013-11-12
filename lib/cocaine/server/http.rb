require 'net/http'
require 'cgi'

require 'cocaine/namespace'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

module Cocaine::Http
  class Request
    attr_reader :method, :version, :query, :headers, :body

    def initialize(rq)
      @ch = rq.read
    end

    def read
      ch = Cocaine::Channel.new
      @ch.callback { |msg|
        @method, url, @version, headers, @body = MessagePack::unpack msg
        @headers = Hash[headers]
        @query = CGI::parse(url)
        ch.trigger self
      }.errback { |err|
        ch.error err
      }
      ch
    end
  end

  class Response
    def initialize(response)
      @response = response
    end

    def write_headers(code, headers)
      @response.write [code, headers]
    end

    def body=(body)
      @response.write body
    end

    def error(errno, reason)
      @response.error errno, reason
    end

    def close
      @response.close
    end
  end

  def http(method_name)
    old_method_name = "#{method_name}_old".to_sym
    alias_method(old_method_name, method_name)
    define_method(method_name) do |rq, rs|
      request = Request.new rq
      response = Response.new rs
      send(old_method_name, request, response)
    end
  end
end