# Redis::Sentinel

monkey patch [redis-rb][0] to support redis sentinel.

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

[0]: https://github.com/redis/redis-rb
