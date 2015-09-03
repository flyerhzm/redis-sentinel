# Redis::Sentinel (Deprecated)

The [redis](https://github.com/redis/redis-rb) gem supports sentinel
from version 3.2, redis-sentinel is not necessary if you are using Redis 2.8.x or later.

Another redis automatic master/slave failover solution for ruby by
using built-in redis sentinel.

It subscribes message with channel "+switch-master", when message
received, it will disconnect current connection and connect to new
master server.

## Installation

Add this line to your application's Gemfile:

    gem 'redis-sentinel'

If you are using redis-server less than 2.6.10, please use
redis-sentinel 1.3.0

    gem 'redis-sentinel', '~> 1.3.0'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-sentinel

## Usage

Specify the sentinel servers and master name

    Redis.new(master_name: "master1", sentinels: [{host: "localhost", port: 26379}, {host: "localhost", port: 26380}])

Sentinels can also be specified using a URI. This URI syntax is required when using Rails.config.cache_store:

    config.cache_store = :redis_store, { master_name: "master1",
                                         sentinels: ['sentinel://localhost:26379', 'sentinel://localhost:26380'] }

After doing the above, you might still see `#<Redis client v3.1.0 for redis://localhost:6379/0>`.
This is fine because redis-sentinel will only try to connect when it is actually required.

However, if none of the sentinel servers can be reached, a Redis::CannotConnectError will be thrown.

There are two additional options:

1. `:failover_reconnect_timeout` (seconds) will block for that long when
   redis is unreachable to give failover enough time to take place. Does
   not wait if not given, or time given is 0.

2. `:failover_reconnect_wait` (seconds) how long to sleep after each
   failed reconnect during a failover event. Defaults to 0.1s.

## Slaves clients

If you need it, you can get an array of Redis clients, each pointing to one of the slaves:

    client = Redis.new(master_name: "master1", sentinels: [{host: "localhost", port: 26379}, {host: "localhost", port: 26380}])
    client.slaves
    # => [#<Redis client v3.0.7 for redis://127.0.0.1:6380/0>, #<Redis client v3.0.7 for redis://127.0.0.1:6381/0>]

You can also get an array of all the clients (master + slaves):

    client = Redis.new(master_name: "master1", sentinels: [{host: "localhost", port: 26379}, {host: "localhost", port: 26380}])
    client.all_clients
    # => [#<Redis client v3.0.7 for redis://127.0.0.1:6379/0>, #<Redis client v3.0.7 for redis://127.0.0.1:6380/0>, #<Redis client v3.0.7 for redis://127.0.0.1:6381/0>]

## Example

Start redis master server, listen on port 16379

```
$ redis-server example/redis-master.conf
```

Start redis slave server, listen on  port 16380

```
$ redis-server example/redis-slave.conf
```

Start 2 sentinel servers

```
$ redis-server example/redis-sentinel1.conf --sentinel
$ redis-server example/redis-sentinel2.conf --sentinel
$ redis-server example/redis-sentinel3.conf --sentinel
```

Run example/test.rb, which will query value of key "foo" every second.

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

## Authors and Contributors

[https://github.com/flyerhzm/redis-sentinel/graphs/contributors](https://github.com/flyerhzm/redis-sentinel/graphs/contributors)

Please fork and contribute, any help in making this project better is appreciated!

This project is a member of the [OSS Manifesto](http://ossmanifesto.org/).

## Copyright

Copyright @ 2012 - 2015 Richard Huang. See [MIT-LICENSE](https://github.com/flyerhzm/redis-sentinel/blob/master/MIT-LICENSE) for details
