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

      @watch_thread = Thread.new { watch_sentinel } if sentinel? && !fetch_option(options, :async)

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
      !!(@master_name && @sentinels_options)
    end

    def auto_retry_with_timeout(&block)
      deadline = @failover_reconnect_timeout.to_i + Time.now.to_f
      begin
        block.call
      rescue Redis::CannotConnectError, Errno::EHOSTDOWN, Errno::EHOSTUNREACH
        raise if Time.now.to_f > deadline
        sleep @failover_reconnect_wait
        retry
      end
    end

    def try_next_sentinel
      sentinel_options = @sentinels_options.shift
      @sentinels_options.push sentinel_options

      @logger.debug "Trying next sentinel: #{sentinel_options[:host]}:#{sentinel_options[:port]}" if @logger && @logger.debug?
      @current_sentinel = Redis.new sentinel_options
    end

    def refresh_sentinels_list
      current_sentinel.sentinel("sentinels", @master_name).each do |response|
        @sentinels_options << {:host => response[3], :port => response[5]}
      end
      @sentinels_options.uniq! {|h| h.values_at(:host, :port) }
    end

    def discover_master
      attempts = 0
      while true
        attempts += 1
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
        rescue Redis::CommandError => e
          raise unless e.message.include?("IDONTKNOW")
        rescue Redis::CannotConnectError, Errno::EHOSTDOWN, Errno::EHOSTUNREACH => e
          # failed to connect to current sentinel server
          raise e if attempts > @sentinels_options.count
        end
      end
    end

    def discover_slaves
      while true
        try_next_sentinel

        begin
          slaves_info = current_sentinel.sentinel("slaves", @master_name)
          @slaves = slaves_info.map do |info|
            info = Hash[*info]
            ::Redis.new(@options.merge(:host => info['ip'], :port => info['port'], :driver => info[:driver]))
          end

          break
        rescue Redis::CommandError => e
          raise unless e.message.include?("IDONTKNOW")
        rescue Redis::CannotConnectError, Errno::EHOSTDOWN, Errno::EHOSTUNREACH
          # failed to connect to current sentinel server
        end
      end
    end

    def slaves
      discover_slaves
      @slaves
    end

    def all_clients
      clients = slaves
      clients.unshift ::Redis.new @options
    end

    def disconnect_with_sentinels
      current_sentinel.client.disconnect if current_sentinel
      @watch_thread.kill if @watch_thread
      disconnect_without_sentinels
    end

    alias disconnect_without_sentinels disconnect
    alias disconnect disconnect_with_sentinels

    def call_with_readonly_protection(*args, &block)
      readonly_protection_with_timeout(:call_without_readonly_protection, *args, &block)
    end

    alias call_without_readonly_protection call
    alias call call_with_readonly_protection

    def call_pipeline_with_readonly_protection(*args, &block)
      readonly_protection_with_timeout(:call_pipeline_without_readonly_protection, *args, &block)
    end

    alias call_pipeline_without_readonly_protection call_pipeline
    alias call_pipeline call_pipeline_with_readonly_protection

    def watch_sentinel
      while true
        sentinel = Redis.new(@sentinels_options[0])

        begin
          sentinel.psubscribe("*") do |on|
            on.pmessage do |pattern, channel, message|
              next if channel != "+switch-master"

              master_name, old_host, old_port, new_host, new_port = message.split(" ")

              next if master_name != @master_name

              @options.merge!(:host => new_host, :port => new_port.to_i)

              @logger.debug "Failover: #{old_host}:#{old_port} => #{new_host}:#{new_port}" if @logger && @logger.debug?

              disconnect
            end
          end
        rescue Redis::CannotConnectError, Errno::EHOSTDOWN, Errno::EHOSTUNREACH
          try_next_sentinel
          sleep 1
        end
      end
    end

  private
    def readonly_protection_with_timeout(method, *args, &block)
      deadline = @failover_reconnect_timeout.to_i + Time.now.to_f
      send(method, *args, &block)
    rescue Redis::CommandError => e
      if e.message.include? "READONLY You can't write against a read only slave."
        reconnect
        raise if Time.now.to_f > deadline
        sleep @failover_reconnect_wait
        retry
      else
        raise
      end
    end

    def fetch_option(options, key)
      options.delete(key) || options.delete(key.to_s)
    end

    def _parse_sentinel_options(options)
      return if options.nil?

      sentinel_options = []
      options.each do |opts|
        opts = opts[:url] if opts.is_a?(Hash) && opts.key?(:url)
        case opts
        when Hash
          sentinel_options << opts
        else
          uri = URI.parse(opts)
          sentinel_options << {
            :host => uri.host,
            :port => uri.port
          }
        end
      end
      sentinel_options
    end
  end
end
