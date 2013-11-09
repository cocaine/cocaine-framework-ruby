$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::Sandbox
  module ERRNO
    NO_SUCH_EVENT = 1
  end

  def initialize
    @handlers = {}
  end

  def on(event, handler)
    @handlers[event] = handler
  end

  def invoke(event, request, response)
    if @handlers.has_key? event
      invoke_handler event, request, response
    else
      write_error ERRNO::NO_SUCH_EVENT, "application has no event '#{event}'", response
    end
  end

  :private
  def invoke_handler(event, request, response)
    $log.debug "invoking '#{event}'"
    handler = @handlers[event]
    handler.execute(request, response)
  end

  :private
  def write_error(errno, reason, response)
    response.error errno, reason
    response.close
  end
end