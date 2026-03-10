# frozen_string_literal: true

class PersistJob < ApplicationJob
  queue_as :findbug

  MAX_EVENTS_PER_RUN = 1000

  def perform
    return unless Findbug.enabled?
    persist_errors
    persist_performance
  end

  private

  def persist_errors
    batch_size = Findbug.config.persist_batch_size
    total = 0

    loop do
      events = Findbug::Storage::RedisBuffer.pop_errors(batch_size)
      break if events.empty?
      events.each do |event_data|
        scrubbed = Findbug::Processing::DataScrubber.scrub(event_data)
        error_event = ErrorEvent.upsert_from_event(scrubbed)
        Findbug::Alerts::Dispatcher.notify(error_event) if error_event
      rescue StandardError => e
        Rails.logger.error("[Findbug] Failed to persist error: #{e.message}")
      end
      total += events.size
      break if total >= MAX_EVENTS_PER_RUN
      sleep(0.01)
    end

    Rails.logger.info("[Findbug] Persisted #{total} error events") if total.positive?
  end

  def persist_performance
    batch_size = Findbug.config.persist_batch_size
    total = 0

    loop do
      events = Findbug::Storage::RedisBuffer.pop_performance(batch_size)
      break if events.empty?
      events.each do |event_data|
        scrubbed = Findbug::Processing::DataScrubber.scrub(event_data)
        PerformanceEvent.create_from_event(scrubbed)
      rescue StandardError => e
        Rails.logger.error("[Findbug] Failed to persist perf event: #{e.message}")
      end
      total += events.size
      break if total >= MAX_EVENTS_PER_RUN
      sleep(0.01)
    end

    Rails.logger.info("[Findbug] Persisted #{total} performance events") if total.positive?
  end
end
