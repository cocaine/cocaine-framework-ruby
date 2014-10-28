require 'rspec'

require 'celluloid/io'

require_relative '../lib/cocaine'

describe 'Locator' do
  it 'should connect' do
    Cocaine::Locator.new
  end

  it 'should connect to the specified endpoint' do
    Cocaine::Locator.new 'localhost', 10053
  end

  it 'should resolve Node service' do
    locator = Cocaine::Locator.new
    tx, rx = locator.resolve :node
    id, info = rx.recv
    Cocaine::LOG.debug "Info: #{id}, #{info}"
  end
end

describe 'Service' do
  it 'should connect to the Node service' do
    Cocaine::Service.new :node
  end

  it 'should connect to the Node service using locator endpoint' do
    Cocaine::Service.new :node, 'localhost', 10053
  end

  it 'should fetch app list from Node service' do
    node = Cocaine::Service.new :node
    tx, rx = node.list
    id, list = rx.recv
    Cocaine::LOG.debug "List: #{id}, #{list}"
  end
end

describe 'Echo' do
  it 'should responds' do
    echo = Cocaine::Service.new :echo
    tx, rx = echo.enqueue :ping
    tx.write 'le message'
    id, message = rx.recv
    expect(id).to eq :write
    expect(message).to eq ['le message']
    Cocaine::LOG.debug "Message: #{id}, #{message}"
  end

  it 'should return error on invalid event' do
    echo = Cocaine::Service.new :echo
    tx, rx = echo.enqueue :invalid
    id, message = rx.recv
    expect(id).to eq :error
    expect(message).not_to eq ['le message']
    Cocaine::LOG.debug "Message: #{id}, #{message}"
  end
end
