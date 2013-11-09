require 'cocaine/error'


class Cocaine::Response
  def initialize(session, dispatcher)
    @session = session
    @dispatcher = dispatcher
    @closed = false
  end

  def write(data)
    check_closed
    @dispatcher.send_chunk @session, data.to_msgpack
  end

  def close
    check_closed
    @closed = true
    @dispatcher.send_choke @session
  end

  :private
  def check_closed
    raise IllegalStateError.new 'Response is already closed' if @closed
  end
end