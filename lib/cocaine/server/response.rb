require 'cocaine/error'


class Cocaine::Response
  def initialize(session, dispatcher)
    @counter = session
    @dispatcher = dispatcher
    @closed = false
  end

  def write(data)
    check_closed
    @dispatcher.send_chunk @counter, data.to_msgpack
  end

  def error(errno, reason)
    check_closed
    @dispatcher.send_error @counter, errno, reason
  end

  def close
    check_closed
    @closed = true
    @dispatcher.send_choke @counter
  end

  private
  def check_closed
    raise IllegalStateError.new 'Response is already closed' if @closed
  end
end