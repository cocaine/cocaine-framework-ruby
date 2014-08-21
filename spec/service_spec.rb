require 'rspec'

require 'celluloid/io'

require_relative '../cocaine'

describe 'Locator' do
  it 'should connect' do
    Cocaine::Locator.new
  end

  it 'should resolve Node service' do
    locator = Cocaine::Locator.new
    tx, rx = locator.resolve :node
    id, info = rx.get
    Cocaine::LOG.debug "Info: #{id}, #{info}"
  end
end

describe 'Service' do
  it 'should connect to the Node service' do
    Cocaine::Service.new :node
  end

  it 'should fetch app list from Node service' do
    node = Cocaine::Service.new :node
    tx, rx = node.list
    id, list = rx.get
    Cocaine::LOG.debug "List: #{id}, #{list}"
  end
end