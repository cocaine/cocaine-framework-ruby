require 'cgi'
require 'net/http'
require 'uri'

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
        tmp_query = URI.parse(url).query
        @query = tmp_query == nil ? {} : CGI.parse(tmp_query)
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


module Cocaine::RackInterface
  def stringio_encode(content)
    io = StringIO.new(content)
    io.binmode
    io.set_encoding "ASCII-8BIT" if io.respond_to? :set_encoding
    io
  end
  
  def execute(request, response)
      df = request.read
      df.callback do |msg|
        method, url, version, headers, body = MessagePack::unpack msg
        # should take a look to RACK SPEC.
		
        env = Hash[*headers.flatten]
        parsed_url = URI.parse("http://#{env['Host']}#{url}")
        default_hostname = parsed_url.hostname  || 'localhost'
        default_port =  parsed_url.port || '80'
		
        env.update({
          "GATEWAY_INTERFACE" => "CGI/1.1",
          "PATH_INFO" => parsed_url.path || '',
          "QUERY_STRING" => parsed_url.query || '',
          "REMOTE_ADDR" => "::1",
          "REMOTE_HOST" => "localhost",
          "REQUEST_METHOD" => method,
          "REQUEST_URI" => url,
          "SCRIPT_NAME" => "",
          "SERVER_NAME" => default_hostname, 
          "SERVER_PORT" => default_port.to_s,
          "SERVER_PROTOCOL" => "HTTP/#{version}",
          "rack.version" => [1, 2],
          "rack.input" =>  stringio_encode(body),
          "rack.errors" => $stderr,
          "rack.multithread" => false,
          "rack.multiprocess" => false,
          "rack.run_once" => false,
          "rack.url_scheme" => "http",
          "HTTP_VERSION" => "HTTP/#{version}",
          "REQUEST_PATH" => parsed_url.path,
        })
		
        code, headers, body = send("call", env)
        response.write([code, headers.to_a])
        body.each {|item| response.write(item) }
        response.close
      end
  end
end

