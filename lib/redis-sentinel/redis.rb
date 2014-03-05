require "redis"

class Redis
  class_eval do
    def slaves
      client.slaves
    end

    def all_clients
      client.all_clients
    end
  end
end
