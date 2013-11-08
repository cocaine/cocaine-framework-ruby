$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::Sandbox
  def initialize
    @handlers = {}
  end

  def on(event, handler)
    @handlers[event] = handler
  end

  def invoke(event, request, response)
    #todo: try/catch block here
    $log.debug "invoking '#{event}'"
    handler = @handlers[event]
    handler.execute(request, response)
  end
end