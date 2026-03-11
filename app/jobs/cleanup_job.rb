# frozen_string_literal: true

class CleanupJob < ApplicationJob
  queue_as :findbug

  BATCH_SIZE = 1000

  def perform
    return unless Findbug.enabled?

    Project.find_each do |project|
      days = project.retention_days
      cleanup_errors(project, days)
      cleanup_performance(project, days)
    end

    Rails.logger.info("[Findbug] Cleanup completed")
  end

  private

  def cleanup_errors(project, days)
    cutoff = days.days.ago
    delete_in_batches(
      project.error_events
             .where(status: [ ErrorEvent::STATUS_RESOLVED, ErrorEvent::STATUS_IGNORED ])
             .where("last_seen_at < ?", cutoff)
    )
    delete_in_batches(
      project.error_events.unresolved.where("last_seen_at < ?", (days * 3).days.ago)
    )
  end

  def cleanup_performance(project, days)
    delete_in_batches(
      project.performance_events.where("captured_at < ?", days.days.ago)
    )
  end

  def delete_in_batches(scope)
    loop do
      deleted = scope.limit(BATCH_SIZE).delete_all
      break if deleted < BATCH_SIZE
    end
  end
end
