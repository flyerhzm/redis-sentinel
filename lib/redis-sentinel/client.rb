require "redis"

class Redis::Client
  DEFAULT_FAILOVER_RECONNECT_WAIT_SECONDS = 0.1

  class_eval do
    def initialize_with_sentinel(options={})
      options = options.dup # Don't touch my options
      @master_name = fetch_option(options, :master_name)
      @master_password = fetch_option(options, :master_password)
      @sentinels = fetch_option(options, :sentinels)
      @sentinels.shuffle! if @sentinels
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
        @logger.debug "Trying next sentinel: #{@sentinels[0][:host]}:#{@sentinels[0][:port]}"
      end
      return @sentinels[0]
    end

    def discover_master
      while true
        sentinel = redis_sentinels[@sentinels[0]]

        begin
          master_host, master_port = sentinel.sentinel("get-master-addr-by-name", @master_name)
          if !master_host && !master_port
            raise Redis::ConnectionError.new("No master named: #{@master_name}")
          end
          is_down, runid = sentinel.sentinel("is-master-down-by-addr", master_host, master_port)
          break
        rescue Redis::CannotConnectError
          try_next_sentinel
        end
      end

      if is_down.to_s == "1" || runid == '?'
        raise Redis::CannotConnectError.new("The master: #{@master_name} is currently not available.")
      else
        @options.merge!(:host => master_host, :port => master_port.to_i, :password => @master_password)
      end
    end

    def disconnect_with_sentinels
      redis_sentinels.each do |config, sentinel|
        sentinel.client.disconnect
      end
      disconnect_without_sentinels
    end

    alias disconnect_without_sentinels disconnect
    alias disconnect disconnect_with_sentinels

    def call_with_readonly_protection(*args, &block)
      tries = 0
      call_without_readonly_protection(*args, &block)
    rescue Redis::CommandError => e
      if e.message == "READONLY You can't write against a read only slave."
        reconnect
        retry if (tries += 1) < 4
      else
        raise
      end
    end

    alias call_without_readonly_protection call
    alias call call_with_readonly_protection

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
