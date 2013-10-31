require 'rspec'

require_relative '../lib/channel'

describe Cocaine::Channel do
  it 'should invoke callback immediately if it has pending data' do
    done = false
    channel = Cocaine::Channel.new
    channel.trigger 'actual'
    channel.callback { |data|
      expect(data).to eq('actual')
      done = true
    }
    done.should == true
  end

  it 'should invoke errback immediately if it has pending errors' do
    done = false
    channel = Cocaine::Channel.new
    channel.error 'actual'
    channel.errback { |data|
      expect(data).to eq('actual')
      done = true
    }
    done.should == true
  end
end