require "redis"

class Redis::Client
  DEFAULT_FAILOVER_RECONNECT_WAIT_SECONDS = 0.1

  class_eval do
    attr_reader :current_sentinel

    def initialize_with_sentinel(options={})
      options = options.dup # Don't touch my options
      @master_name = fetch_option(options, :master_name)
      @master_password = fetch_option(options, :master_password)
      @sentinels_options = _parse_sentinel_options(fetch_option(options, :sentinels))
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
      @master_name && @sentinels_options
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
      sentinel_options = @sentinels_options.shift
      @sentinels_options.push sentinel_options
      if sentinel_options
        @logger.debug "Trying next sentinel: #{sentinel_options[:host]}:#{sentinel_options[:port]}" if @logger && @logger.debug?
        @current_sentinel = Redis.new sentinel_options
      else
        raise Redis::CannotConnectError
      end
    end

    def refresh_sentinels_list
      responses = current_sentinel.sentinel("sentinels", @master_name)
      @sentinels_options = responses.map do |response|
        {:host => response[3], :port => response[5]}
      end.unshift(:host => current_sentinel.host, :port => current_sentinel.port)
    end

    def discover_master
      while true
        try_next_sentinel

        begin
          master_host, master_port = current_sentinel.sentinel("get-master-addr-by-name", @master_name)
          if master_host && master_port
            # An ip:port pair
            @options.merge!(:host => master_host, :port => master_port.to_i, :password => @master_password)
            refresh_sentinels_list
            break
          else
            # A null reply
          end
        rescue Redis::CommandError
          # An -IDONTKNOWN reply
        rescue Redis::CannotConnectError
          # faile to connect to current sentinel server
        end
      end
    end

    def disconnect_with_sentinels
      current_sentinel.client.disconnect if current_sentinel
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

    def _parse_sentinel_options(options)
      return if options.nil?

      sentinel_options = []
      options.each do |sentinel_option|
        if sentinel_option.is_a?(Hash)
          sentinel_options << sentinel_option
        else
          uri = URI.parse(sentinel_option)
          sentinel_options << {
              host: uri.host,
              port: uri.port
          }
        end
      end
      sentinel_options
    end
  end
end
