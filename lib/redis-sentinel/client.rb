require "redis"

class Redis::Client
  class_eval do
    def initialize_with_sentinel(options={})
      @master_name = options.delete(:master_name) || options.delete("master_name")
      @sentinels = options.delete(:sentinels) || options.delete("sentinels")
      initialize_without_sentinel(options)
    end

    alias initialize_without_sentinel initialize
    alias initialize initialize_with_sentinel

    def connect_with_sentinel
      discover_master if sentinel?
      connect_without_sentinel
    end

    alias connect_without_sentinel connect
    alias connect connect_with_sentinel

    def sentinel?
      @master_name && @sentinels
    end

    def try_next_sentinel
      @sentinels << @sentinels.shift
      if @logger && @logger.debug?
        @logger.debug? "Trying next sentinel: #{@sentinels[0][:host]}:#{@sentinels[0][:port]}"
      end
      return @sentinels[0]
    end

    def redis_sentinels
      @redis_sentinels ||= Hash.new do |hash, config|
        hash[config] = Redis.new(config)
      end
    end

    def discover_master
      while true
        sentinel = redis_sentinels[@sentinels[0]]

        begin
          host, port = sentinel.sentinel("get-master-addr-by-name", @master_name)
          if !host && !port
            raise Redis::ConnectionError.new("No master named: #{@master_name}")
          end
          @options.merge!(:host => host, :port => port.to_i)

          break
        rescue Redis::CannotConnectError
          try_next_sentinel
        end
      end
    end
  end
end
