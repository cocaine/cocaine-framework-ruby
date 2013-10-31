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

  it 'should invoke callback after triggering' do
    done = false
    channel = Cocaine::Channel.new
    channel.callback { |data|
      expect(data).to eq('actual')
      done = true
    }
    channel.trigger 'actual'
    done.should == true
  end

  it 'should invoke errback after triggering' do
    done = false
    channel = Cocaine::Channel.new
    channel.errback { |data|
      expect(data).to eq('actual')
      done = true
    }
    channel.error 'actual'
    done.should == true
  end

  it 'should invoke all callbacks after closed' do
    counter = 0

    channel = Cocaine::Channel.new
    channel.trigger 'actual'
    channel.trigger 'actual'

    channel.callback { |data|
      expect(data).to eq('actual')
      counter += 1
    }
    channel.close

    counter.should == 2
  end

end