require 'test/unit'

require 'eventmachine'

require_relative '../lib/service'

class ServiceTest < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_locator
    EventMachine.run do
      locator = Cocaine::Locator.new
      connection = locator.resolve('node')
      connection.callback { |endpoint, version, api|
        assert_true(endpoint[0].is_a?(String))
        assert_true(1024 <= endpoint[1] && endpoint[1] <= 65535)
        assert_equal(1, version)
        assert_equal({0=>'start_app',1 => 'pause_app', 2 => 'list'}, api)
        EventMachine.stop()
      }
      connection.errback { |errno, reason|
        fail("[#{errno}] #{reason}")
        EventMachine.stop()
      }
    end
  end
end