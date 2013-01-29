# Redis::Sentinel

another redis automatic master/slave failover solution for ruby by
using built-in redis sentinel.

it subscribes message with channel "+switch-master", when message
received, it will disconnect current connection and connect to new
master server.

## Installation

Add this line to your application's Gemfile:

    gem 'redis-sentinel'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-sentinel

## Usage

Specify the sentinel servers and master name

    Redis.new(master_name: "master1", sentinels: [{host: "localhost", port: 26379}, {host: "localhost", port: 26380}])

There are two additional options: 

1. `:failover_reconnect_timeout` (seconds) will block for that long when
   redis is unreachable to give failover enough time to take place. Does
   not wait if not given, or time given is 0.

2. `:failover_reconnect_wait` (seconds) how long to sleep after each
   failed reconnect during a failover event. Defaults to 0.1s.

## Example

start redis master server, listen on port 16379

```
$ redis-server example/redis-master.conf
```

start redis slave server, listen on  port 16380

```
$ redis-server example/redis-slave.conf
```

start 2 sentinel servers

```
$ redis-server example/redis-sentinel1.conf --sentinel
$ redis-server example/redis-sentinel2.conf --sentinel
```

run example/test.rb, which will query value of key "foo" every second.

```
$ bundle exec ruby example/test.rb
```

You will see output "bar" every second. Let's try the failover process.

1. Stop redis master server.
2. You will see error message output.
3. Redis sentinel promote redis slave server to master. During this time
   you will see errors instead of "bar" while the failover is happening.
4. Then you will see correct "bar" output every second again.

## Example of Failover Timeout
Run the same example code above but run:

```
$ bundle exec ruby example/test_wait_for_failover.rb
```

You will see the stream of "bar" will stop while failover is taking
place and will resume once it has completed, provided that failover
takes less than 30 seconds.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

[0]: https://github.com/redis/redis-rb
