# frozen_string_literal: true

class ErrorEvent < ApplicationRecord
  self.table_name = "findbug_error_events"

  belongs_to :project, optional: true

  STATUS_UNRESOLVED = "unresolved"
  STATUS_RESOLVED = "resolved"
  STATUS_IGNORED = "ignored"

  SEVERITY_ERROR = "error"
  SEVERITY_WARNING = "warning"
  SEVERITY_INFO = "info"

  validates :fingerprint, presence: true
  validates :exception_class, presence: true
  validates :status, inclusion: { in: [STATUS_UNRESOLVED, STATUS_RESOLVED, STATUS_IGNORED] }
  validates :severity, inclusion: { in: [SEVERITY_ERROR, SEVERITY_WARNING, SEVERITY_INFO] }

  scope :unresolved, -> { where(status: STATUS_UNRESOLVED) }
  scope :resolved, -> { where(status: STATUS_RESOLVED) }
  scope :ignored, -> { where(status: STATUS_IGNORED) }
  scope :errors, -> { where(severity: SEVERITY_ERROR) }
  scope :warnings, -> { where(severity: SEVERITY_WARNING) }
  scope :recent, -> { order(last_seen_at: :desc) }
  scope :by_occurrence, -> { order(occurrence_count: :desc) }
  scope :last_24_hours, -> { where("last_seen_at >= ?", 24.hours.ago) }
  scope :last_7_days, -> { where("last_seen_at >= ?", 7.days.ago) }
  scope :last_30_days, -> { where("last_seen_at >= ?", 30.days.ago) }

  def self.upsert_from_event(event_data)
    fingerprint = event_data[:fingerprint]
    project_id = event_data[:project_id]

    transaction do
      existing = where(fingerprint: fingerprint, project_id: project_id).first

      if existing
        existing.occurrence_count += 1
        existing.last_seen_at = Time.current
        existing.context = merge_contexts(existing.context, event_data[:context])
        existing.status = STATUS_UNRESOLVED if existing.status == STATUS_RESOLVED
        existing.save!
        existing
      else
        create!(
          fingerprint: fingerprint,
          exception_class: event_data[:exception_class],
          message: event_data[:message],
          backtrace: serialize_backtrace(event_data[:backtrace]),
          context: event_data[:context] || {},
          request_data: event_data[:context]&.dig(:request) || event_data[:request_data] || {},
          environment: event_data[:environment],
          release_version: event_data[:release],
          severity: event_data[:severity] || SEVERITY_ERROR,
          source: event_data[:source] || "sentry_sdk",
          handled: event_data[:handled] || false,
          occurrence_count: 1,
          first_seen_at: Time.current,
          last_seen_at: Time.current,
          status: STATUS_UNRESOLVED,
          project_id: project_id
        )
      end
    end
  end

  def resolve!
    update!(status: STATUS_RESOLVED)
  end

  def ignore!
    update!(status: STATUS_IGNORED)
  end

  def reopen!
    update!(status: STATUS_UNRESOLVED)
  end

  def backtrace_lines
    return [] unless backtrace
    backtrace.is_a?(Array) ? backtrace : JSON.parse(backtrace)
  rescue JSON::ParserError
    backtrace.to_s.split("\n")
  end

  def user
    context&.dig("user") || context&.dig(:user)
  end

  def request
    context&.dig("request") || context&.dig(:request)
  end

  def breadcrumbs
    context&.dig("breadcrumbs") || context&.dig(:breadcrumbs) || []
  end

  def tags
    context&.dig("tags") || context&.dig(:tags) || {}
  end

  def summary
    "#{exception_class}: #{message&.truncate(100)}"
  end

  private

  def self.merge_contexts(old_context, new_context)
    return new_context if old_context.blank?
    return old_context if new_context.blank?
    old_context.deep_merge(new_context)
  end

  def self.serialize_backtrace(backtrace)
    return nil unless backtrace
    backtrace.is_a?(Array) ? backtrace.to_json : backtrace
  end
end
