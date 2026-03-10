# frozen_string_literal: true

require "monitor"

module Findbug
  module Storage
    class CircuitBreaker
      FAILURE_THRESHOLD = 5
      RECOVERY_TIME = 30

      class << self
        def allow?
          synchronize do
            case state
            when :closed then true
            when :open
              if recovery_period_elapsed?
                transition_to(:half_open)
                true
              else
                false
              end
            when :half_open then true
            end
          end
        end

        def record_success
          synchronize do
            @failures = 0
            transition_to(:closed)
          end
        end

        def record_failure
          synchronize do
            @failures = (@failures || 0) + 1
            if state == :half_open
              transition_to(:open)
            elsif @failures >= FAILURE_THRESHOLD
              transition_to(:open)
            end
          end
        end

        def state
          @state || :closed
        end

        def failure_count
          @failures || 0
        end

        def reset!
          synchronize do
            @state = :closed
            @failures = 0
            @opened_at = nil
          end
        end

        private

        def synchronize(&block)
          @monitor ||= Monitor.new
          @monitor.synchronize(&block)
        end

        def transition_to(new_state)
          @state = new_state
          @opened_at = Time.now if new_state == :open
        end

        def recovery_period_elapsed?
          return true unless @opened_at
          Time.now - @opened_at >= RECOVERY_TIME
        end
      end
    end
  end
end
