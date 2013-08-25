# Redis::Sentinel

Another redis automatic master/slave failover solution for ruby by
using built-in redis sentinel.

It subscribes message with channel "+switch-master", when message
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

* [Richard Huang](https://github.com/flyerhzm) - Creator of the project
* [Donald Plummer](https://github.com/dplummer) - Add wait / timeout for
  redis connection
* [Rafał Michalski](https://github.com/royaltm) - Ensure promoted slave
  become master / Add redis synchrony support
* [Zachary Anker](https://github.com/zanker) - Add redis authentication
  support
* [Nick Deteffen](https://github.com/nick-desteffen) - Add ability to
  reconnect all redis sentinel clients
* [Carlos Paramio](https://github.com/carlosparamio) - Avoid the config
  gets modified
* [Michael Gee](https://github.com/mikegee) - Reconnect if redis suddenly
  becomes read-only.

Please fork and contribute, any help in making this project better is appreciated!

This project is a member of the [OSS Manifesto](http://ossmanifesto.org/).

## Copyright

Copyright @ 2012 - 2013 Richard Huang. See [MIT-LICENSE](https://github.com/flyerhzm/redis-sentinel/blob/master/MIT-LICENSE) for details
