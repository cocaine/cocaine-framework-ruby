require 'logger'

$log = Logger.new(STDERR)
$log.level = Logger::DEBUG


class Cocaine::Dispatcher
  def initialize(conn)
    @conn = conn
    @conn.on_message do |session, message|
      process session, message
    end
  end

  protected
  def process(session, message)
    raise NotImplementedError
  end
end