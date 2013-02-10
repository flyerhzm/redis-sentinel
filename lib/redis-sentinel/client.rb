require "redis"

class Redis::Client
  DEFAULT_FAILOVER_RECONNECT_WAIT_SECONDS = 0.1

  class_eval do
    def initialize_with_sentinel(options={})
      @master_name = fetch_option(options, :master_name)
      @sentinels = fetch_option(options, :sentinels)
      @failover_reconnect_timeout = fetch_option(options, :failover_reconnect_timeout)
      @failover_reconnect_wait = fetch_option(options, :failover_reconnect_wait) ||
                                 DEFAULT_FAILOVER_RECONNECT_WAIT_SECONDS

      initialize_without_sentinel(options)
    end

    alias initialize_without_sentinel initialize
    alias initialize initialize_with_sentinel

    def connect_with_sentinel
      if sentinel?
        auto_retry_with_timeout do
          discover_master
          connect_without_sentinel
        end
      else
        connect_without_sentinel
      end
    end

    alias connect_without_sentinel connect
    alias connect connect_with_sentinel

    def sentinel?
      @master_name && @sentinels
    end

    def auto_retry_with_timeout(&block)
      deadline = @failover_reconnect_timeout.to_i + Time.now.to_f
      begin
        block.call
      rescue Redis::CannotConnectError
        raise if Time.now.to_f > deadline
        sleep @failover_reconnect_wait
        retry
      end
    end

    def try_next_sentinel
      @sentinels << @sentinels.shift
      if @logger && @logger.debug?
        @logger.debug? "Trying next sentinel: #{@sentinels[0][:host]}:#{@sentinels[0][:port]}"
      end
      return @sentinels[0]
    end

    def discover_master
      while true
        sentinel = redis_sentinels[@sentinels[0]]

        begin
          host, port = sentinel.sentinel("get-master-addr-by-name", @master_name)
          if !host && !port
            raise Redis::ConnectionError.new("No master named: #{@master_name}")
          end
          is_down, runid = sentinel.sentinel("is-master-down-by-addr", host, port)
        rescue Redis::CannotConnectError
          try_next_sentinel
        end
        if is_down == "1" || runid == '?'
          raise Redis::CannotConnectError.new("The master: #{@master_name} is currently not available.")
        else
          @options.merge!(:host => host, :port => port.to_i)
        end

        break
      end
    end

  private

    def fetch_option(options, key)
      options.delete(key) || options.delete(key.to_s)
    end

    def redis_sentinels
      @redis_sentinels ||= Hash.new do |hash, config|
        hash[config] = Redis.new(config)
      end
    end
  end
end
