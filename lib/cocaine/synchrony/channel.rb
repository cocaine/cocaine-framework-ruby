require 'fiber'
require 'em-synchrony'

require 'cocaine/namespace'

class Cocaine::Synchrony::Channel
  def initialize(channel)
    @channel = channel
    @pending = []

    fb = Fiber.current

    @channel.callback { |result|
      if fb.alive?
        fb.resume result
      else
        @pending.push result
      end
    }

    @channel.errback { |err|
      if fb.alive?
        if err.instance_of? Choke
          fb.resume err
        else
          raise ServiceError.new err
        end
      else
        @pending.push err
      end
    }
  end

  def read
    if @pending.empty?
      Fiber.yield
    else
      chunk = @pending.pop
      if chunk.instance_of? Exception
        raise chunk
      else
        chunk
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

  :private
  def collect_until_count(count)
    chunks = []
    while count > 0
      chunks.push Fiber.yield
      count -= 1
    end
    chunks
  end

  :private
  def collect_until_choke
    chunks = []

    loop do
      chunk = Fiber.yield
      break if chunk.instance_of? Choke
      chunks.push chunk
      puts "#{chunk}, #{chunks}"
    end

    chunks
  end
end