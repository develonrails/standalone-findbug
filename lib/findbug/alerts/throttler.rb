# frozen_string_literal: true

module Findbug
  module Alerts
    class Throttler
      THROTTLE_KEY_PREFIX = "findbug:alert:throttle:"

      class << self
        def throttled?(fingerprint)
          Storage::ConnectionPool.with { |redis| redis.exists?(throttle_key(fingerprint)) }
        rescue StandardError
          false
        end

        def record(fingerprint)
          key = throttle_key(fingerprint)
          Storage::ConnectionPool.with { |redis| redis.setex(key, throttle_period, Time.now.utc.iso8601) }
        rescue StandardError
          nil
        end

        def clear(fingerprint)
          Storage::ConnectionPool.with { |redis| redis.del(throttle_key(fingerprint)) }
        rescue StandardError
          nil
        end

        private

        def throttle_key(fingerprint)
          "#{THROTTLE_KEY_PREFIX}#{fingerprint}"
        end

        def throttle_period
          Findbug.config.alerts.throttle_period
        end
      end
    end
  end
end
