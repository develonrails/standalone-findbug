# frozen_string_literal: true

class CleanupJob < ApplicationJob
  queue_as :findbug

  BATCH_SIZE = 1000

  def perform
    return unless Findbug.enabled?
    cleanup_errors
    cleanup_performance
    Rails.logger.info("[Findbug] Cleanup completed")
  end

  private

  def cleanup_errors
    cutoff = retention_days.days.ago
    delete_in_batches(
      ErrorEvent.where(status: [ ErrorEvent::STATUS_RESOLVED, ErrorEvent::STATUS_IGNORED ])
                .where("last_seen_at < ?", cutoff)
    )
    # Very old unresolved errors (3x retention)
    delete_in_batches(
      ErrorEvent.unresolved.where("last_seen_at < ?", (retention_days * 3).days.ago)
    )
  end

  def cleanup_performance
    delete_in_batches(
      PerformanceEvent.where("captured_at < ?", retention_days.days.ago)
    )
  end

  def delete_in_batches(scope)
    loop do
      ids = scope.limit(BATCH_SIZE).pluck(:id)
      break if ids.empty?
      scope.where(id: ids).delete_all
      sleep(0.01)
    end
  end

  def retention_days
    Findbug.config.retention_days
  end
end
