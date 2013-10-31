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
        assert_equal(['3hren.dev.yandex.net', 49667], endpoint)
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