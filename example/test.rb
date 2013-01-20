require 'redis'
require 'redis-sentinel'

redis = Redis.new(:master_name => "example-test",
                  :sentinels => [
                    {:host => "localhost", :port => 26379},
                    {:host => "localhost", :port => 26380}
                  ])
redis.set "foo", "bar"

while true
  begin
    puts redis.get "foo"
  rescue => e
    puts "failed?", e
  end
  sleep 1
end
