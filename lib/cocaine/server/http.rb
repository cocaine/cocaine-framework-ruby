require 'cocaine/namespace'

module Cocaine::Http
  def self.http_request(method_name)
    # 1. msgpack request data into [method, url, version, headers, body]
    # 2. make ruby http request
    # 3. pass it.
    # 4. make ruby http response
    # 5. pass it.
  end

  http_request :execute
end