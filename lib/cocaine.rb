$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'logger'

module Cocaine
  LOG = Logger.new STDERR
  LOG.level = ENV['WORKER_LOG_LEVEL'] || Logger::DEBUG
end

require 'cocaine/version'
require 'cocaine/cocaine'
