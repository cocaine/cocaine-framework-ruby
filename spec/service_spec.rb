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
    id, info = rx.receive
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
    id, list = rx.receive
    Cocaine::LOG.debug "List: #{id}, #{list}"
  end
end

describe 'Echo' do
  it 'should responds' do
    echo = Cocaine::Service.new :echo
    tx, rx = echo.enqueue :ping
    tx.write 'le message'
    tx.write 'le message'
    tx.error 1, 'le message'
    tx.write 'le message'
    message = rx.receive
    expect(message == 'le message')
  end
end