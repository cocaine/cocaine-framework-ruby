require_relative 'namespace'


class Cocaine::Decoder
  def feed(data, &block)
    @decoder ||= MessagePack::Unpacker.new
    @decoder.feed_each(data) do |decoded|
      block.call decoded
    end
  end
end