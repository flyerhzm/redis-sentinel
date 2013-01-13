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

1. stop redis master server
2. you will see error message output
3. redis sentinel promote redis slave server to master
4. then you will see correct "bar" output every second again

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

[0]: https://github.com/redis/redis-rb
