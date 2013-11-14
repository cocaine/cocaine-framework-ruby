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

  # todo: maybe make some kind of generator method?
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
    futures = []
    while count > 0
      futures.push Fiber.yield
      count -= 1
    end

    results = []
    futures.each do |future|
      results.push future.get
    end
    results
  end

  private
  def collect_until_choke
    results = []
    loop do
      future = Fiber.yield
      begin
        results.push future.get
      rescue ChokeEvent
        break
      end
    end
    results
  end
end