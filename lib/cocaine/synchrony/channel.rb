require 'fiber'
require 'em-synchrony'

require 'cocaine/namespace'

class Cocaine::Synchrony::Channel
  def initialize(channel)
    @pending = []
    register_fiber channel
  end

  def read
    if @pending.empty?
      future = Fiber.yield
    else
      future = @pending.pop
    end
    future.get
  end

  def each
    loop do
      begin
        yield Fiber.yield.get
      rescue ChokeEvent
        return
      end
    end
  end

  def collect(count=0)
    if count == 0
      collect_until_choke
    else
      collect_until_count count
    end
  end

  private
  def register_fiber(channel)
    fb = Fiber.current
    channel.callback { |future|
      if fb.alive?
        fb.resume future
      else
        @pending.push future
      end
    }
  end

  private
  def collect_until_count(count)
    results = []
    each do |chunk|
      results.push chunk
      count -= 1
      if count == 0
        break
      end
    end
    results
  end

  private
  def collect_until_choke
    results = []
    each do |chunk|
      results.push chunk
    end
    results
  end
end