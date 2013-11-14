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
      result = Fiber.yield
      if result.instance_of? Choke
        result
      elsif result.instance_of? Exception
        raise result
      else
        result
      end
    else
      pop_pending
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

    channel.callback { |result|
      if fb.alive?
        fb.resume result
      else
        @pending.push result
      end
    }

    channel.errback { |err|
      if fb.alive?
        if err.instance_of? Choke
          fb.resume err
        else
          fb.resume ServiceError.new err
        end
      else
        @pending.push err
      end
    }
  end

  private
  def pop_pending
    chunk = @pending.pop
    if chunk.instance_of? Exception
      raise chunk
    else
      chunk
    end
  end

  private
  def collect_until_count(count)
    chunks = []
    while count > 0
      chunks.push Fiber.yield
      count -= 1
    end
    chunks
  end

  private
  def collect_until_choke
    chunks = []
    loop do
      chunk = Fiber.yield
      break if chunk.instance_of? Choke
      chunks.push chunk
    end
    chunks
  end
end