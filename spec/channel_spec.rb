require 'rspec'

require_relative '../lib/channel'

describe Cocaine::Channel do
  it 'should invoke callback immediately if it has pending data' do
    channel = Cocaine::Channel.new
    channel.trigger 'actual'
    channel.callback { |data| expect(data).to eq('actual') }
  end
end