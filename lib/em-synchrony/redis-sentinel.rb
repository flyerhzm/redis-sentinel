require 'redis/connection/synchrony' unless defined? Redis::Connection::Synchrony
require 'redis-sentinel'

class Redis::Client
  class_eval do
    private
    def sleep(seconds)
      f = Fiber.current
      EM::Timer.new(seconds) { f.resume }
      Fiber.yield
    end
  end
end
