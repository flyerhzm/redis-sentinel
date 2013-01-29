require 'redis'
require 'redis-sentinel'

redis = Redis.new(:master_name => "example-test",
                  :sentinels => [
                    {:host => "localhost", :port => 26379},
                    {:host => "localhost", :port => 26380}
                  ],
                  :failover_reconnect_timeout => 30)
redis.set "foo", "bar"

while true
  begin
    puts redis.get "foo"
  rescue => e
    puts "failover took too long to recover", e
  end
  sleep 1
end
