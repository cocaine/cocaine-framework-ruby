class Cocaine::Request
  def initialize(channel)
    @ch = channel
  end

  def read
    @ch
  end
end