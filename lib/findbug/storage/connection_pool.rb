# frozen_string_literal: true

require "redis"
require "connection_pool"

module Findbug
  module Storage
    class ConnectionPool
      class << self
        def with(&block)
          pool.with(&block)
        end

        def pool
          @pool ||= create_pool
        end

        def shutdown!
          @pool&.shutdown { |redis| redis.close }
          @pool = nil
        end

        def healthy?
          with { |redis| redis.ping == "PONG" }
        rescue StandardError
          false
        end

        private

        def create_pool
          config = Findbug.config
          ::ConnectionPool.new(
            size: config.redis_pool_size,
            timeout: config.redis_pool_timeout
          ) do
            Redis.new(
              url: config.redis_url,
              connect_timeout: 1.0,
              read_timeout: 1.0,
              write_timeout: 1.0,
              reconnect_attempts: 1
            )
          end
        end
      end
    end
  end
end
