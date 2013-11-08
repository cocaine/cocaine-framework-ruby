class Cocaine::Request
  def initialize(channel)
    @channel = channel
  end

  def read
    @channel
  end
end