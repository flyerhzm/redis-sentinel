require 'redis'
require 'redis-sentinel'

redis = Redis.new(:master_name => "example-test",
                  :sentinels => [
                    {:host => "localhost", :port => 26379},
                    {:host => "localhost", :port => 26380}
                  ],
                  :failover_reconnect_timeout => 30,
                  :failover_reconnect_wait => 0.0001)

redis.set "foo", 1

while true
  begin
    puts redis.incr "foo"
  rescue Redis::CannotConnectError => e
    puts "failover took too long to recover", e
  end
  sleep 1
end
