# frozen_string_literal: true

require "json"

module Findbug
  module Storage
    class RedisBuffer
      ERRORS_KEY = "findbug:errors"
      PERFORMANCE_KEY = "findbug:performance"

      class << self
        def push_error(event_data)
          push_async(ERRORS_KEY, event_data)
        end

        def push_performance(event_data)
          push_async(PERFORMANCE_KEY, event_data)
        end

        def pop_errors(batch_size = 100)
          pop_batch(ERRORS_KEY, batch_size)
        end

        def pop_performance(batch_size = 100)
          pop_batch(PERFORMANCE_KEY, batch_size)
        end

        def stats
          ConnectionPool.with do |redis|
            {
              error_queue_length: redis.llen(ERRORS_KEY),
              performance_queue_length: redis.llen(PERFORMANCE_KEY),
              circuit_breaker_state: CircuitBreaker.state,
              circuit_breaker_failures: CircuitBreaker.failure_count
            }
          end
        rescue StandardError => e
          {
            error_queue_length: 0,
            performance_queue_length: 0,
            circuit_breaker_state: CircuitBreaker.state,
            circuit_breaker_failures: CircuitBreaker.failure_count,
            error: "Redis connection failed: #{e.message}"
          }
        end

        def clear!
          ConnectionPool.with do |redis|
            redis.del(ERRORS_KEY, PERFORMANCE_KEY)
          end
        rescue StandardError
          nil
        end

        private

        def push_async(key, event_data)
          return unless Findbug.enabled?
          return unless CircuitBreaker.allow?

          Thread.new do
            perform_push(key, event_data)
          rescue StandardError => e
            CircuitBreaker.record_failure
            Findbug.logger.debug("[Findbug] Failed to push event to Redis: #{e.message}")
          end
          nil
        end

        def perform_push(key, event_data)
          ConnectionPool.with do |redis|
            event_data[:captured_at] ||= Time.now.utc.iso8601(3)
            redis.lpush(key, event_data.to_json)
            redis.ltrim(key, 0, Findbug.config.max_buffer_size - 1)
            CircuitBreaker.record_success
          end
        end

        def pop_batch(key, batch_size)
          events = []
          ConnectionPool.with do |redis|
            batch_size.times do
              json = redis.rpop(key)
              break unless json
              events << JSON.parse(json, symbolize_names: true)
            rescue JSON::ParserError => e
              Findbug.logger.error("[Findbug] Failed to parse event: #{e.message}")
            end
          end
          events
        end
      end
    end
  end
end
